using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

var builder = WebApplication.CreateBuilder(args);
var demoConfiguration = new ConfigurationBuilder()
    .SetBasePath(builder.Environment.ContentRootPath)
    .AddJsonFile("appsettings.Demo.json", optional: true, reloadOnChange: true)
    .Build();

builder.Services.AddOpenApi();
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});
builder.Services.AddHttpContextAccessor();

var connStr = builder.Configuration.GetConnectionString("MySql");

if (string.IsNullOrWhiteSpace(connStr))
    throw new InvalidOperationException("ConnectionStrings:MySql is not configured");

var demoWebhookSecretConfig = demoConfiguration.GetValue<string>("DemoWebhookSettings:Secret");
var demoStorageConfigured = demoConfiguration.GetValue<bool>("DemoSettings:Isolated")
    && !string.IsNullOrWhiteSpace(demoWebhookSecretConfig);

builder.Services.AddSingleton(sp => new DbRouter(
    new DbService(connStr),
    demoStorageConfigured ? new DbService(connStr, "demo_") : null,
    sp.GetRequiredService<IHttpContextAccessor>()));

var app = builder.Build();

// Demo uses the same process/port. Rewrite its namespaced URLs to the existing
// handlers while keeping request-scoped storage and MT5 state isolated.
app.Use(async (context, next) =>
{
    PathString remaining;
    var isDemoRequest = false;

    if (context.Request.Path.StartsWithSegments("/demo/api", out remaining))
    {
        isDemoRequest = true;
        context.Request.Path = new PathString("/api").Add(remaining);
    }
    else if (context.Request.Path.Equals("/demo/webhook"))
    {
        isDemoRequest = true;
        context.Request.Path = "/webhook";
    }

    if (isDemoRequest)
    {
        context.Items[DbRouter.InstanceKey] = "demo";
        if (!demoStorageConfigured)
        {
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            await context.Response.WriteAsJsonAsync(new
            {
                ok = false,
                instance = "demo",
                error = "Demo storage is not configured. Create backend/appsettings.Demo.json."
            });
            return;
        }
    }

    await next();
});

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseCors("AllowAll");

if (app.Environment.IsDevelopment())
    app.MapOpenApi();

// ─── Startup: migrate legacy JSON only (schema is managed by SQL scripts) ───
var db = app.Services.GetRequiredService<DbRouter>();

var legacyDbPath = Path.Combine(app.Environment.ContentRootPath, "signals_db.json");
if (File.Exists(legacyDbPath))
{
    try
    {
        var legacyJson = await File.ReadAllTextAsync(legacyDbPath);
        var legacySignals = JsonSerializer.Deserialize<List<Signal>>(legacyJson,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        if (legacySignals?.Count > 0)
        {
            foreach (var s in legacySignals)
                await db.UpsertSignalAsync(s);
            File.Move(legacyDbPath, legacyDbPath + ".migrated", overwrite: true);
            Console.WriteLine($"[MySQL] Migrated {legacySignals.Count} signals from JSON → MySQL");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[MySQL] Migration failed: {ex.Message}");
    }
}

// ─── Global config ───────────────────────────────────────────────────
var webhookSecret = app.Configuration.GetValue<string>("WebhookSettings:Secret")
    ?? "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f";
var demoWebhookSecret = demoWebhookSecretConfig ?? webhookSecret;

var rawJsonOptions = new JsonSerializerOptions
{
    PropertyNamingPolicy = null,
    WriteIndented = true
};
var jsonOpts = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    WriteIndented = true
};

// ─── MT5 in-memory state (isolated per Main/Demo request) ────────────
var httpContextAccessor = app.Services.GetRequiredService<IHttpContextAccessor>();
var runtime = new TradingRuntimeRouter(httpContextAccessor);
string ActiveWebhookSecret() => runtime.IsDemo ? demoWebhookSecret : webhookSecret;

// Load latest snapshot from MySQL on startup
try
{
    var latestSnapshot = await db.GetLatestAccountSnapshotAsync();
    if (latestSnapshot != null)
    {
        runtime.Balance    = latestSnapshot.Balance;
        runtime.Equity     = latestSnapshot.Equity;
        runtime.FreeMargin = latestSnapshot.FreeMargin;
        runtime.Bid        = latestSnapshot.Bid;
        runtime.Ask        = latestSnapshot.Ask;
        if (!string.IsNullOrWhiteSpace(latestSnapshot.PositionsJson))
        {
            runtime.Positions = JsonSerializer.Deserialize<List<HeartbeatPosition>>(latestSnapshot.PositionsJson, jsonOpts)
                                ?? new List<HeartbeatPosition>();
        }
        runtime.LastHeartbeat = latestSnapshot.Timestamp;
        Console.WriteLine($"[MySQL] Restored latest snapshot from {latestSnapshot.Timestamp} (Positions: {runtime.Positions.Count})");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"[MySQL] Error restoring latest snapshot on startup: {ex.Message}");
}

double currentPrice = 3980.0;
var random = new Random();

// ─── Webhook: รับสัญญาณจาก TradingView ──────────────────────────────
app.MapPost("/webhook", async (HttpContext context) =>
{
    string body = "";
    try
    {
        using var reader = new StreamReader(context.Request.Body);
        body = await reader.ReadToEndAsync();

        var payload = JsonSerializer.Deserialize<WebhookPayload>(body, jsonOpts);
        if (payload == null)
        {
            await db.AddLogAsync("?", body, null, "Invalid JSON payload");
            return Results.BadRequest(new { ok = false, error = "Invalid JSON payload" });
        }

        if (payload.Token != ActiveWebhookSecret())
        {
            await db.AddLogAsync(payload.Action ?? "?", body, null, "Unauthorized");
            return Results.Json(new { ok = false, error = "Unauthorized" }, statusCode: 401);
        }

        var signals = await db.ReadSignalsAsync();
        var action  = payload.Action?.ToUpper();

        if (action is "BUY" or "SELL")
        {
            if (!string.IsNullOrWhiteSpace(payload.SignalId) &&
                signals.Any(s => s.SignalId == payload.SignalId))
            {
                var dup = new { ok = true, duplicate = true, message = "Signal already logged", signalId = payload.SignalId };
                await db.AddLogAsync(action, body, JsonSerializer.Serialize(dup));
                return Results.Ok(dup);
            }

            var newSignal = new Signal
            {
                Id        = !string.IsNullOrWhiteSpace(payload.SignalId)
                            ? payload.SignalId
                            : DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString(),
                SignalId   = payload.SignalId ?? "",
                Timestamp  = DateTime.UtcNow,
                BarTime    = payload.BarTime,
                Timeframe  = payload.Timeframe ?? "",
                Action     = action,
                Symbol     = payload.Symbol ?? "XAUUSD",
                Sl         = payload.Sl,
                Tp         = payload.Tp,
                Rr         = payload.Rr,
                EntryPrice = payload.EntryPrice > 0 ? payload.EntryPrice : 0.0,
                Volume     = payload.Volume    > 0 ? payload.Volume    : 0.01,
                Status     = action == "BUY" ? "PENDING_BUY" : "PENDING_SELL",
                Comment    = payload.Comment ?? ""
            };

            await db.UpsertSignalAsync(newSignal);
            var res = new { ok = true, message = $"{action} signal queued (PENDING)", signalId = newSignal.Id, mode = "mql5_ea" };
            await db.AddLogAsync(action, body, JsonSerializer.Serialize(res));
            return Results.Ok(res);
        }

        if (action is "CLOSE" or "CLOSE_SIGNAL")
        {
            Signal? target = null;

            if (!string.IsNullOrWhiteSpace(payload.SignalId))
                target = signals
                    .Where(s => s.Status == "OPEN" && s.SignalId == payload.SignalId)
                    .OrderByDescending(s => s.Timestamp).FirstOrDefault();

            target ??= signals
                .Where(s => s.Status == "OPEN" &&
                            s.Symbol.Equals(payload.Symbol ?? "XAUUSD", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(s => s.Timestamp).FirstOrDefault();

            if (target == null)
            {
                var err = new { ok = false, error = "No open signals found to close" };
                await db.AddLogAsync(action, body, JsonSerializer.Serialize(err));
                return Results.Ok(err);
            }

            target.Status = "PENDING_CLOSE";
            if (payload.ExitPrice > 0) target.ExitPrice = payload.ExitPrice;
            if (payload.Profit   != 0) target.Profit    = payload.Profit;

            await db.UpsertSignalAsync(target);
            var closeRes = new { ok = true, message = $"Signal {target.Id} queued for close (PENDING_CLOSE)", ticket = target.Ticket, mode = "mql5_ea" };
            await db.AddLogAsync(action, body, JsonSerializer.Serialize(closeRes));
            return Results.Ok(closeRes);
        }

        var bad = new { ok = false, error = $"Unsupported action: {action}" };
        await db.AddLogAsync(action ?? "?", body, null, bad.error);
        return Results.BadRequest(bad);
    }
    catch (Exception ex)
    {
        await db.AddLogAsync("ERROR", body, null, ex.Message);
        return Results.Json(new { ok = false, error = ex.Message }, statusCode: 500);
    }
});

// ─── GET /api/signals ────────────────────────────────────────────────
app.MapGet("/api/signals", async () =>
    Results.Ok(await db.ReadSignalsAsync()));

// ─── POST /api/signals/pending — Heartbeat from EA ───────────────────
app.MapPost("/api/signals/pending", async ([FromBody] HeartbeatPayload payload) =>
{
    if (payload.Token != ActiveWebhookSecret())
        return Results.Json(new { ok = false, error = "Unauthorized" }, statusCode: 401);

    // Update in-memory MT5 state
    runtime.LastHeartbeat = DateTime.UtcNow;
    runtime.Balance       = payload.Balance;
    runtime.Equity        = payload.Equity;
    runtime.FreeMargin    = payload.FreeMargin;
    runtime.Bid           = payload.Bid;
    runtime.Ask           = payload.Ask;
    runtime.Positions     = payload.Positions;
    runtime.Connected     = true;

    // Persist snapshot to MySQL (fire-and-forget style to not slow heartbeat)
    var posJson = JsonSerializer.Serialize(payload.Positions);
    _ = db.AddAccountSnapshotAsync(payload.Balance, payload.Equity, payload.FreeMargin,
                                    payload.Bid, payload.Ask, payload.Positions.Count, posJson);

    var signals = await db.ReadSignalsAsync();
    var pending = signals.Where(s => s.Status.StartsWith("PENDING_")).ToList();
    return Results.Ok(pending);
});

// ─── POST /api/signals/update — EA reports open/close result ─────────
app.MapPost("/api/signals/update", async ([FromBody] SignalUpdatePayload payload) =>
{
    if (payload.Token != ActiveWebhookSecret())
        return Results.Json(new { ok = false, error = "Unauthorized" }, statusCode: 401);

    var signal = await db.GetSignalByIdAsync(payload.Id);
    if (signal == null)
        return Results.NotFound(new { ok = false, error = "Signal not found" });

    signal.Status = payload.Status.ToUpper();
    if (!string.IsNullOrWhiteSpace(payload.Ticket)) signal.Ticket     = payload.Ticket;
    if (payload.EntryPrice > 0)                      signal.EntryPrice = payload.EntryPrice;
    if (payload.ExitPrice  > 0)                      signal.ExitPrice  = payload.ExitPrice;
    if (payload.Profit     != 0)                     signal.Profit     = payload.Profit;

    await db.UpsertSignalAsync(signal);
    await db.AddLogAsync($"UPDATE_{signal.Status}", JsonSerializer.Serialize(payload),
                          JsonSerializer.Serialize(new { ok = true, message = $"Signal updated to {signal.Status}" }));

    return Results.Ok(new { ok = true, message = $"Signal updated to {signal.Status}" });
});

// ─── POST /api/signals/local — EA reports a local open/close trade ────
app.MapPost("/api/signals/local", async ([FromBody] LocalTradePayload payload) =>
{
    if (payload.Token != ActiveWebhookSecret())
        return Results.Json(new { ok = false, error = "Unauthorized" }, statusCode: 401);

    var signal = await db.GetSignalByIdAsync(payload.Id) ?? new Signal();
    
    signal.Id         = payload.Id;
    signal.SignalId   = payload.Id;
    if (signal.Timestamp == default) signal.Timestamp = DateTime.UtcNow;
    if (!string.IsNullOrWhiteSpace(payload.Action)) signal.Action = payload.Action.ToUpper();
    if (!string.IsNullOrWhiteSpace(payload.Symbol)) signal.Symbol = payload.Symbol;
    if (payload.Volume > 0)    signal.Volume     = payload.Volume;
    if (payload.EntryPrice > 0) signal.EntryPrice = payload.EntryPrice;
    if (payload.Sl > 0)        signal.Sl         = payload.Sl;
    if (payload.Tp > 0)        signal.Tp         = payload.Tp;
    if (!string.IsNullOrWhiteSpace(payload.Status)) signal.Status = payload.Status.ToUpper();
    if (!string.IsNullOrWhiteSpace(payload.Ticket)) signal.Ticket = payload.Ticket;
    if (payload.ExitPrice > 0) signal.ExitPrice  = payload.ExitPrice;
    if (payload.Profit != 0)   signal.Profit     = payload.Profit;

    await db.UpsertSignalAsync(signal);
    await db.AddLogAsync($"LOCAL_{signal.Status}", JsonSerializer.Serialize(payload),
                          JsonSerializer.Serialize(new { ok = true, message = $"Local signal upserted as {signal.Status}" }));

    return Results.Ok(new { ok = true, message = $"Local signal upserted as {signal.Status}" });
});

// ─── POST /api/signals/clear ──────────────────────────────────────────
app.MapPost("/api/signals/clear", async () =>
{
    await db.ClearSignalsAsync();
    return Results.Ok(new { ok = true, message = "All signals cleared from MySQL" });
});

// ─── GET /api/webhook/log ─────────────────────────────────────────────
app.MapGet("/api/webhook/log", async () =>
    Results.Ok(await db.GetRecentLogsAsync(20)));

// ─── GET /api/status ──────────────────────────────────────────────────
app.MapGet("/api/status", async () =>
{
    var signals      = await db.ReadSignalsAsync();
    var openCount    = signals.Count(s => s.Status == "OPEN");
    var pendingCount = signals.Count(s => s.Status.StartsWith("PENDING_"));
    var isConnected  = (DateTime.UtcNow - runtime.LastHeartbeat).TotalSeconds < 10;

    return Results.Json(new
    {
        ok               = true,
        instance         = runtime.Instance,
        environment      = app.Environment.EnvironmentName,
        mode             = "mql5_ea",
        open_trades      = openCount,
        pending_signals  = pendingCount,
        mt5_connected    = isConnected,
        message          = "ระบบพร้อมเชื่อมต่อกับ MQL5 EA เรียบร้อย"
    }, rawJsonOptions);
});

// ─── POST /api/connect / disconnect ──────────────────────────────────
app.MapPost("/api/connect",    () => { runtime.Connected = true;  return Results.Ok(new { ok = true, message = "Connected to MT5"    }); });
app.MapPost("/api/disconnect", () => { runtime.Connected = false; return Results.Ok(new { ok = true, message = "Disconnected from MT5" }); });

// ─── GET /api/account ────────────────────────────────────────────────
app.MapGet("/api/account", () =>
{
    var isConnected = (DateTime.UtcNow - runtime.LastHeartbeat).TotalSeconds < 10;
    if (!isConnected)
        return Results.Json(new { ok = false, error = "MT5 Not Connected" }, statusCode: 400);

    return Results.Json(new
    {
        balance     = Math.Round(runtime.Balance, 2),
        equity      = Math.Round(runtime.Equity, 2),
        margin      = Math.Round(runtime.Equity * 0.8, 2),
        free_margin = Math.Round(runtime.FreeMargin, 2),
        profit      = Math.Round(runtime.Equity - runtime.Balance, 2),
        currency    = "USD",
        login       = 279661518,
        name        = "Exness Demo Account",
        server      = "Exness-Demo"
    }, rawJsonOptions);
});

// ─── GET /api/price ───────────────────────────────────────────────────
app.MapGet("/api/price", () =>
{
    var isConnected = (DateTime.UtcNow - runtime.LastHeartbeat).TotalSeconds < 10;
    double bid = runtime.Bid;
    double ask = runtime.Ask;

    if (!isConnected || runtime.Bid == 0)
    {
        currentPrice += (random.NextDouble() - 0.5) * 0.2;
        currentPrice  = Math.Round(currentPrice, 2);
        bid = currentPrice - 0.05;
        ask = currentPrice + 0.05;
    }

    double spread = Math.Round((ask - bid) * 100.0, 1);
    return Results.Json(new
    {
        symbol    = "XAUUSD",
        bid       = Math.Round(bid, 2),
        ask       = Math.Round(ask, 2),
        spread    = spread,
        timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
    }, rawJsonOptions);
});

// ─── GET /api/positions ───────────────────────────────────────────────
app.MapGet("/api/positions", () =>
{
    var isConnected = (DateTime.UtcNow - runtime.LastHeartbeat).TotalSeconds < 10;
    if (!isConnected) return Results.Json(new List<object>(), rawJsonOptions);

    var list = runtime.Positions.Select(p => (object)new
    {
        ticket        = p.Ticket,
        symbol        = p.Symbol,
        type          = p.Type,
        volume        = p.Volume,
        open_price    = p.OpenPrice,
        current_price = p.CurrentPrice,
        sl            = p.Sl,
        tp            = p.Tp,
        profit        = p.Profit,
        comment       = ""
    }).ToList();

    return Results.Json(list, rawJsonOptions);
});

// ─── GET /api/history ─────────────────────────────────────────────────
app.MapGet("/api/history", async () =>
{
    var signals      = await db.ReadSignalsAsync();
    var closedSignals = signals.Where(s => s.Status is "WIN" or "LOSS" or "CLOSED").ToList();

    var list = closedSignals.Select(s =>
    {
        var closePrice = s.ExitPrice > 0
            ? s.ExitPrice
            : s.EntryPrice + (s.Profit / (s.Volume * 100.0));
        return (object)new
        {
            ticket     = s.Ticket,
            symbol     = s.Symbol,
            type       = s.Action.ToUpper(),
            volume     = s.Volume,
            price      = Math.Round(closePrice, 4),
            open_price = Math.Round(s.EntryPrice, 4),
            close_price= Math.Round(closePrice, 4),
            profit     = Math.Round(s.Profit, 2),
            timestamp  = new DateTimeOffset(s.Timestamp).ToUnixTimeMilliseconds(),
            time       = s.Timestamp.ToString("yyyy-MM-ddTHH:mm:ssZ"),
            status     = s.Status,
            swap       = 0.0,
            comment    = s.Comment
        };
    }).ToList();

    return Results.Json(list, rawJsonOptions);
});

// ─── GET /api/risk ────────────────────────────────────────────────────
app.MapGet("/api/risk", async () =>
{
    var signals     = await db.ReadSignalsAsync();
    var today       = DateTime.UtcNow.Date;
    var dailyPnl    = signals
        .Where(s => (s.Status == "WIN" || s.Status == "LOSS" || s.Status == "CLOSED")
                    && s.Timestamp.Date == today)
        .Sum(s => s.Profit);

    var isConnected    = (DateTime.UtcNow - runtime.LastHeartbeat).TotalSeconds < 10;
    var openPositions  = isConnected
        ? runtime.Positions.Count
        : signals.Count(s => s.Status == "OPEN");

    return Results.Json(new
    {
        max_positions = 3,
        fixed_lot     = 0.05,
        max_daily_loss= 100.0,
        daily_pnl     = Math.Round(dailyPnl, 2),
        open_positions= openPositions
    }, rawJsonOptions);
});

// ─── POST /api/trade ──────────────────────────────────────────────────
app.MapPost("/api/trade", async (HttpContext context) =>
{
    if (!runtime.Connected)
        return Results.Json(new { ok = false, error = "MT5 Not Connected" }, statusCode: 400);

    using var reader = new StreamReader(context.Request.Body);
    var body = await reader.ReadToEndAsync();
    using var doc  = JsonDocument.Parse(body);
    var root       = doc.RootElement;

    var action = root.GetProperty("action").GetString()?.ToUpper() ?? "BUY";
    var sl     = root.TryGetProperty("sl", out var slProp) ? slProp.GetDouble() : 0.0;
    var tp     = root.TryGetProperty("tp", out var tpProp) ? tpProp.GetDouble() : 0.0;

    var newSignal = new Signal
    {
        Id        = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString(),
        Timestamp = DateTime.UtcNow,
        Action    = action,
        Symbol    = "XAUUSD",
        Sl        = sl,
        Tp        = tp,
        Volume    = 0.01,
        Status    = action == "BUY" ? "PENDING_BUY" : "PENDING_SELL",
        Comment   = "Manual Web Trade"
    };

    await db.UpsertSignalAsync(newSignal);
    return Results.Ok(new { ok = true, message = $"Manual {action} order sent", signalId = newSignal.Id });
});

// ─── POST /api/close/{ticket} ────────────────────────────────────────
app.MapPost("/api/close/{ticket}", async (string ticket) =>
{
    var signals = await db.ReadSignalsAsync();
    var target  = signals.FirstOrDefault(s => s.Ticket == ticket && s.Status == "OPEN");
    if (target == null)
        return Results.NotFound(new { ok = false, error = "Open position not found" });

    target.Status = "PENDING_CLOSE";
    await db.UpsertSignalAsync(target);
    return Results.Ok(new { ok = true, message = "Close signal queued", ticket });
});

// ─── POST /api/close-all ─────────────────────────────────────────────
app.MapPost("/api/close-all", async () =>
{
    var signals     = await db.ReadSignalsAsync();
    var openSignals = signals.Where(s => s.Status == "OPEN").ToList();
    if (openSignals.Count == 0)
        return Results.Ok(new { ok = true, message = "No open positions to close" });

    foreach (var s in openSignals)
    {
        s.Status = "PENDING_CLOSE";
        await db.UpsertSignalAsync(s);
    }
    return Results.Ok(new { ok = true, message = "Close all signals queued" });
});

// ─── POST /api/modify/{ticket} ───────────────────────────────────────
app.MapPost("/api/modify/{ticket}", async (string ticket, HttpContext context) =>
{
    using var reader = new StreamReader(context.Request.Body);
    var body = await reader.ReadToEndAsync();
    using var doc  = JsonDocument.Parse(body);
    var root       = doc.RootElement;

    var sl = root.TryGetProperty("sl", out var slProp) ? slProp.GetDouble() : 0.0;
    var tp = root.TryGetProperty("tp", out var tpProp) ? tpProp.GetDouble() : 0.0;

    var signals = await db.ReadSignalsAsync();
    var target  = signals.FirstOrDefault(s => s.Ticket == ticket && s.Status == "OPEN");
    if (target == null)
        return Results.NotFound(new { ok = false, error = "Open position not found" });

    target.Sl = sl;
    target.Tp = tp;
    await db.UpsertSignalAsync(target);
    return Results.Ok(new { ok = true, message = "SL/TP queued for modification", ticket });
});

app.MapFallbackToFile("index.html");

app.Run();

public sealed class DbRouter
{
    public const string InstanceKey = "ATS.Instance";

    private readonly DbService _main;
    private readonly DbService? _demo;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public DbRouter(DbService main, DbService? demo, IHttpContextAccessor httpContextAccessor)
    {
        _main = main;
        _demo = demo;
        _httpContextAccessor = httpContextAccessor;
    }

    private bool IsDemo => string.Equals(
        _httpContextAccessor.HttpContext?.Items[InstanceKey] as string,
        "demo",
        StringComparison.OrdinalIgnoreCase);

    private DbService Current => IsDemo
        ? _demo ?? throw new InvalidOperationException("Demo storage is not configured")
        : _main;

    public Task<List<Signal>> ReadSignalsAsync() => Current.ReadSignalsAsync();
    public Task<Signal?> GetSignalByIdAsync(string id) => Current.GetSignalByIdAsync(id);
    public Task UpsertSignalAsync(Signal signal) => Current.UpsertSignalAsync(signal);
    public Task ClearSignalsAsync() => Current.ClearSignalsAsync();
    public Task AddLogAsync(string action, string body, string? result, string? error = null) =>
        Current.AddLogAsync(action, body, result, error);
    public Task<List<WebhookLogEntry>> GetRecentLogsAsync(int count = 20) =>
        Current.GetRecentLogsAsync(count);
    public Task<AccountSnapshotEntity?> GetLatestAccountSnapshotAsync() =>
        Current.GetLatestAccountSnapshotAsync();
    public Task AddAccountSnapshotAsync(double balance, double equity, double freeMargin,
        double bid, double ask, int openPositions, string positionsJson) =>
        Current.AddAccountSnapshotAsync(balance, equity, freeMargin, bid, ask, openPositions, positionsJson);
}

public sealed class TradingRuntimeRouter
{
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly TradingRuntimeState _main = new();
    private readonly TradingRuntimeState _demo = new();

    public TradingRuntimeRouter(IHttpContextAccessor httpContextAccessor) =>
        _httpContextAccessor = httpContextAccessor;

    public bool IsDemo => string.Equals(
        _httpContextAccessor.HttpContext?.Items[DbRouter.InstanceKey] as string,
        "demo",
        StringComparison.OrdinalIgnoreCase);

    private TradingRuntimeState Current => IsDemo ? _demo : _main;

    public string Instance => IsDemo ? "demo" : "main";
    public DateTime LastHeartbeat { get => Current.LastHeartbeat; set => Current.LastHeartbeat = value; }
    public double Balance { get => Current.Balance; set => Current.Balance = value; }
    public double Equity { get => Current.Equity; set => Current.Equity = value; }
    public double FreeMargin { get => Current.FreeMargin; set => Current.FreeMargin = value; }
    public double Bid { get => Current.Bid; set => Current.Bid = value; }
    public double Ask { get => Current.Ask; set => Current.Ask = value; }
    public List<HeartbeatPosition> Positions { get => Current.Positions; set => Current.Positions = value; }
    public bool Connected { get => Current.Connected; set => Current.Connected = value; }
}

public sealed class TradingRuntimeState
{
    public DateTime LastHeartbeat { get; set; } = DateTime.MinValue;
    public double Balance { get; set; }
    public double Equity { get; set; }
    public double FreeMargin { get; set; }
    public double Bid { get; set; }
    public double Ask { get; set; }
    public List<HeartbeatPosition> Positions { get; set; } = new();
    public bool Connected { get; set; }
}

// ═══════════════════════════════════════════════════════════════════
// DbService — all MySQL operations
// ═══════════════════════════════════════════════════════════════════
public class DbService
{
    private readonly string _connStr;
    private readonly string _signalsTable;
    private readonly string _webhookLogsTable;
    private readonly string _accountSnapshotsTable;

    public DbService(string connStr, string tablePrefix = "")
    {
        if (tablePrefix is not ("" or "demo_"))
            throw new ArgumentException("Unsupported database table prefix", nameof(tablePrefix));

        _connStr = connStr;
        _signalsTable = $"{tablePrefix}signals";
        _webhookLogsTable = $"{tablePrefix}webhook_logs";
        _accountSnapshotsTable = $"{tablePrefix}account_snapshots";
    }

    private MySqlConnection Open() => new MySqlConnection(_connStr);

    // ── Create tables ────────────────────────────────────────────────
    // ── Read all signals ─────────────────────────────────────────────
    public async Task<List<Signal>> ReadSignalsAsync()
    {
        await using var conn = Open();
        await conn.OpenAsync();

        var sql = $"SELECT * FROM `{_signalsTable}` ORDER BY timestamp ASC";
        await using var cmd = new MySqlCommand(sql, conn);
        await using var rdr = await cmd.ExecuteReaderAsync();

        var list = new List<Signal>();
        while (await rdr.ReadAsync())
            list.Add(MapSignal(rdr));
        return list;
    }

    // ── Get single signal by id ──────────────────────────────────────
    public async Task<Signal?> GetSignalByIdAsync(string id)
    {
        await using var conn = Open();
        await conn.OpenAsync();

        var sql = $"SELECT * FROM `{_signalsTable}` WHERE id = @id LIMIT 1";
        await using var cmd = new MySqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@id", id);
        await using var rdr = await cmd.ExecuteReaderAsync();
        return await rdr.ReadAsync() ? MapSignal(rdr) : null;
    }

    // ── Upsert signal ─────────────────────────────────────────────────
    public async Task UpsertSignalAsync(Signal s)
    {
        await using var conn = Open();
        await conn.OpenAsync();

        var sql = $@"
INSERT INTO `{_signalsTable}`
    (id, signal_id, timestamp, bar_time, timeframe, action, symbol,
     sl, tp, rr, entry_price, exit_price, profit, volume, ticket, status, comment)
VALUES
    (@id, @signal_id, @timestamp, @bar_time, @timeframe, @action, @symbol,
     @sl, @tp, @rr, @entry_price, @exit_price, @profit, @volume, @ticket, @status, @comment)
ON DUPLICATE KEY UPDATE
    signal_id   = VALUES(signal_id),
    bar_time    = VALUES(bar_time),
    timeframe   = VALUES(timeframe),
    action      = VALUES(action),
    symbol      = VALUES(symbol),
    sl          = VALUES(sl),
    tp          = VALUES(tp),
    rr          = VALUES(rr),
    entry_price = VALUES(entry_price),
    exit_price  = VALUES(exit_price),
    profit      = VALUES(profit),
    volume      = VALUES(volume),
    ticket      = VALUES(ticket),
    status      = VALUES(status),
    comment     = VALUES(comment);
";
        await using var cmd = new MySqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@id",          s.Id);
        cmd.Parameters.AddWithValue("@signal_id",   s.SignalId);
        cmd.Parameters.AddWithValue("@timestamp",   s.Timestamp);
        cmd.Parameters.AddWithValue("@bar_time",    s.BarTime);
        cmd.Parameters.AddWithValue("@timeframe",   s.Timeframe);
        cmd.Parameters.AddWithValue("@action",      s.Action);
        cmd.Parameters.AddWithValue("@symbol",      s.Symbol);
        cmd.Parameters.AddWithValue("@sl",          s.Sl);
        cmd.Parameters.AddWithValue("@tp",          s.Tp);
        cmd.Parameters.AddWithValue("@rr",          s.Rr);
        cmd.Parameters.AddWithValue("@entry_price", s.EntryPrice);
        cmd.Parameters.AddWithValue("@exit_price",  s.ExitPrice);
        cmd.Parameters.AddWithValue("@profit",      s.Profit);
        cmd.Parameters.AddWithValue("@volume",      s.Volume);
        cmd.Parameters.AddWithValue("@ticket",      s.Ticket);
        cmd.Parameters.AddWithValue("@status",      s.Status);
        cmd.Parameters.AddWithValue("@comment",     s.Comment);
        await cmd.ExecuteNonQueryAsync();
    }

    // ── Clear all signals ─────────────────────────────────────────────
    public async Task ClearSignalsAsync()
    {
        await using var conn = Open();
        await conn.OpenAsync();
        await using var cmd = new MySqlCommand($"TRUNCATE TABLE `{_signalsTable}`", conn);
        await cmd.ExecuteNonQueryAsync();
    }

    // ── Add webhook log ───────────────────────────────────────────────
    public async Task AddLogAsync(string action, string body, string? result, string? error = null)
    {
        try
        {
            await using var conn = Open();
            await conn.OpenAsync();

            var sql = $@"
INSERT INTO `{_webhookLogsTable}` (timestamp, action, body, result, error)
VALUES (@ts, @action, @body, @result, @error)";
            await using var cmd = new MySqlCommand(sql, conn);
            cmd.Parameters.AddWithValue("@ts",     DateTime.UtcNow);
            cmd.Parameters.AddWithValue("@action", action);
            cmd.Parameters.AddWithValue("@body",   body.Length > 65000 ? body[..65000] : body);
            cmd.Parameters.AddWithValue("@result", (object?)result ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@error",  (object?)error  ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[MySQL] AddLog error: {ex.Message}");
        }
    }

    // ── Get recent logs ───────────────────────────────────────────────
    public async Task<List<WebhookLogEntry>> GetRecentLogsAsync(int count = 20)
    {
        await using var conn = Open();
        await conn.OpenAsync();

        var sql = $"SELECT * FROM `{_webhookLogsTable}` ORDER BY timestamp DESC LIMIT {count}";
        await using var cmd = new MySqlCommand(sql, conn);
        await using var rdr = await cmd.ExecuteReaderAsync();

        var list = new List<WebhookLogEntry>();
        while (await rdr.ReadAsync())
        {
            list.Add(new WebhookLogEntry
            {
                Timestamp = DateTime.SpecifyKind(rdr.GetDateTime("timestamp"), DateTimeKind.Utc),
                Action    = rdr.GetString("action"),
                Body      = rdr.GetString("body"),
                Result    = rdr.IsDBNull(rdr.GetOrdinal("result")) ? null : rdr.GetString("result"),
                Error     = rdr.IsDBNull(rdr.GetOrdinal("error"))  ? null : rdr.GetString("error"),
            });
        }
        return list;
    }

    // ── Get latest account snapshot ──────────────────────────────────
    public async Task<AccountSnapshotEntity?> GetLatestAccountSnapshotAsync()
    {
        try
        {
            await using var conn = Open();
            await conn.OpenAsync();

            var sql = $"SELECT * FROM `{_accountSnapshotsTable}` ORDER BY timestamp DESC LIMIT 1";
            await using var cmd = new MySqlCommand(sql, conn);
            await using var rdr = await cmd.ExecuteReaderAsync();

            if (await rdr.ReadAsync())
            {
                return new AccountSnapshotEntity
                {
                    Timestamp = DateTime.SpecifyKind(rdr.GetDateTime("timestamp"), DateTimeKind.Utc),
                    Balance = rdr.GetDouble("balance"),
                    Equity = rdr.GetDouble("equity"),
                    FreeMargin = rdr.GetDouble("free_margin"),
                    Bid = rdr.GetDouble("bid"),
                    Ask = rdr.GetDouble("ask"),
                    OpenPositions = rdr.GetInt32("open_positions"),
                    PositionsJson = rdr.IsDBNull(rdr.GetOrdinal("positions_json")) 
                        ? string.Empty 
                        : rdr.GetString("positions_json")
                };
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[MySQL] GetLatestAccountSnapshot error: {ex.Message}");
        }
        return null;
    }

    // ── Save account snapshot ─────────────────────────────────────────
    public async Task AddAccountSnapshotAsync(double balance, double equity, double freeMargin,
                                               double bid, double ask, int openPositions, string positionsJson)
    {
        try
        {
            await using var conn = Open();
            await conn.OpenAsync();

            await using var trans = await conn.BeginTransactionAsync();
            try
            {
                // Delete previous snapshots to keep only the latest one
                var deleteSql = $"DELETE FROM `{_accountSnapshotsTable}`";
                await using (var delCmd = new MySqlCommand(deleteSql, conn, trans))
                {
                    await delCmd.ExecuteNonQueryAsync();
                }

                // Insert the new one
                var insertSql = $@"
INSERT INTO `{_accountSnapshotsTable}`
    (timestamp, balance, equity, free_margin, bid, ask, open_positions, positions_json)
VALUES (@ts, @balance, @equity, @free_margin, @bid, @ask, @open_positions, @positions_json)";
                await using (var cmd = new MySqlCommand(insertSql, conn, trans))
                {
                    cmd.Parameters.AddWithValue("@ts",             DateTime.UtcNow);
                    cmd.Parameters.AddWithValue("@balance",        balance);
                    cmd.Parameters.AddWithValue("@equity",         equity);
                    cmd.Parameters.AddWithValue("@free_margin",    freeMargin);
                    cmd.Parameters.AddWithValue("@bid",            bid);
                    cmd.Parameters.AddWithValue("@ask",            ask);
                    cmd.Parameters.AddWithValue("@open_positions", openPositions);
                    cmd.Parameters.AddWithValue("@positions_json",  positionsJson);
                    await cmd.ExecuteNonQueryAsync();
                }

                await trans.CommitAsync();
            }
            catch (Exception)
            {
                await trans.RollbackAsync();
                throw;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[MySQL] AddAccountSnapshot error: {ex.Message}");
        }
    }

    // ── Map DataReader → Signal ───────────────────────────────────────
    private static Signal MapSignal(MySqlDataReader r) => new Signal
    {
        Id         = r.GetString("id"),
        SignalId   = r.GetString("signal_id"),
        Timestamp  = DateTime.SpecifyKind(r.GetDateTime("timestamp"), DateTimeKind.Utc),
        BarTime    = r.GetInt64("bar_time"),
        Timeframe  = r.GetString("timeframe"),
        Action     = r.GetString("action"),
        Symbol     = r.GetString("symbol"),
        Sl         = r.GetDouble("sl"),
        Tp         = r.GetDouble("tp"),
        Rr         = r.GetDouble("rr"),
        EntryPrice = r.GetDouble("entry_price"),
        ExitPrice  = r.GetDouble("exit_price"),
        Profit     = r.GetDouble("profit"),
        Volume     = r.GetDouble("volume"),
        Ticket     = r.GetString("ticket"),
        Status     = r.GetString("status"),
        Comment    = r.GetString("comment"),
    };
}

// ═══════════════════════════════════════════════════════════════════
// Models
// ═══════════════════════════════════════════════════════════════════
public class AccountSnapshotEntity
{
    public DateTime Timestamp { get; set; }
    public double Balance { get; set; }
    public double Equity { get; set; }
    public double FreeMargin { get; set; }
    public double Bid { get; set; }
    public double Ask { get; set; }
    public int OpenPositions { get; set; }
    public string PositionsJson { get; set; } = string.Empty;
}

public class Signal
{
    public string Id        { get; set; } = string.Empty;

    [JsonPropertyName("signalId")]
    public string SignalId  { get; set; } = string.Empty;

    public DateTime Timestamp { get; set; }

    [JsonPropertyName("barTime")]
    public long BarTime     { get; set; }

    public string Timeframe { get; set; } = string.Empty;
    public string Action    { get; set; } = string.Empty;
    public string Symbol    { get; set; } = string.Empty;
    public double Sl        { get; set; }
    public double Tp        { get; set; }
    public double Rr        { get; set; }

    [JsonPropertyName("entryPrice")]
    public double EntryPrice { get; set; }

    [JsonPropertyName("exitPrice")]
    public double ExitPrice  { get; set; }

    public double Profit  { get; set; }
    public double Volume  { get; set; }
    public string Ticket  { get; set; } = string.Empty;
    public string Status  { get; set; } = "PENDING_BUY";
    public string Comment { get; set; } = string.Empty;
}

public class WebhookPayload
{
    public string Token   { get; set; } = string.Empty;
    public string Action  { get; set; } = string.Empty;
    public string Symbol  { get; set; } = string.Empty;

    [JsonPropertyName("signal_id")]
    public string SignalId { get; set; } = string.Empty;

    public double Sl     { get; set; }
    public double Tp     { get; set; }
    public double Rr     { get; set; }
    public double Volume { get; set; }

    [JsonPropertyName("entry_price")]
    public double EntryPrice { get; set; }

    [JsonPropertyName("exit_price")]
    public double ExitPrice  { get; set; }

    public double Profit    { get; set; }
    public string Result    { get; set; } = string.Empty;
    public string Comment   { get; set; } = string.Empty;
    public string Timeframe { get; set; } = string.Empty;

    [JsonPropertyName("bar_time")]
    public long BarTime { get; set; }
}

public class WebhookLogEntry
{
    public DateTime Timestamp { get; set; }
    public string   Action    { get; set; } = string.Empty;
    public string   Body      { get; set; } = string.Empty;
    public string?  Result    { get; set; }
    public string?  Error     { get; set; }
}

public class SignalUpdatePayload
{
    [JsonPropertyName("token")]       public string Token  { get; set; } = string.Empty;
    [JsonPropertyName("id")]          public string Id     { get; set; } = string.Empty;
    [JsonPropertyName("status")]      public string Status { get; set; } = string.Empty;
    [JsonPropertyName("ticket")]      public string Ticket { get; set; } = string.Empty;
    [JsonPropertyName("entry_price")] public double EntryPrice { get; set; }
    [JsonPropertyName("exit_price")]  public double ExitPrice  { get; set; }
    [JsonPropertyName("profit")]      public double Profit     { get; set; }
}

public class HeartbeatPayload
{
    [JsonPropertyName("token")]      public string Token     { get; set; } = string.Empty;
    [JsonPropertyName("balance")]    public double Balance   { get; set; }
    [JsonPropertyName("equity")]     public double Equity    { get; set; }
    [JsonPropertyName("free_margin")]public double FreeMargin{ get; set; }
    [JsonPropertyName("bid")]        public double Bid       { get; set; }
    [JsonPropertyName("ask")]        public double Ask       { get; set; }
    [JsonPropertyName("positions")]  public List<HeartbeatPosition> Positions { get; set; } = new();
}

public class HeartbeatPosition
{
    [JsonPropertyName("ticket")]        public string Ticket       { get; set; } = string.Empty;
    [JsonPropertyName("symbol")]        public string Symbol       { get; set; } = string.Empty;
    [JsonPropertyName("type")]          public string Type         { get; set; } = string.Empty;
    [JsonPropertyName("volume")]        public double Volume       { get; set; }
    [JsonPropertyName("open_price")]    public double OpenPrice    { get; set; }
    [JsonPropertyName("current_price")] public double CurrentPrice { get; set; }
    [JsonPropertyName("sl")]            public double Sl           { get; set; }
    [JsonPropertyName("tp")]            public double Tp           { get; set; }
    [JsonPropertyName("profit")]        public double Profit       { get; set; }
}

public class LocalTradePayload
{
    [JsonPropertyName("token")]       public string Token { get; set; } = string.Empty;
    [JsonPropertyName("id")]          public string Id { get; set; } = string.Empty;
    [JsonPropertyName("action")]      public string Action { get; set; } = string.Empty;
    [JsonPropertyName("symbol")]      public string Symbol { get; set; } = string.Empty;
    [JsonPropertyName("volume")]      public double Volume { get; set; }
    [JsonPropertyName("entry_price")] public double EntryPrice { get; set; }
    [JsonPropertyName("sl")]          public double Sl { get; set; }
    [JsonPropertyName("tp")]          public double Tp { get; set; }
    [JsonPropertyName("status")]      public string Status { get; set; } = string.Empty;
    [JsonPropertyName("ticket")]      public string Ticket { get; set; } = string.Empty;
    [JsonPropertyName("exit_price")]  public double ExitPrice { get; set; }
    [JsonPropertyName("profit")]      public double Profit { get; set; }
}
