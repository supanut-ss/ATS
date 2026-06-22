using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

app.UseCors("AllowAll");
app.UseDefaultFiles();
app.UseStaticFiles();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

var webhookSecret = app.Configuration.GetValue<string>("WebhookSettings:Secret") ?? "ats_sec_9f5c4b8e2a1d7f0e3c6b8a9f";
var jsonOpts = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    WriteIndented = true
};
var dbPath = Path.Combine(app.Environment.ContentRootPath, "signals_db.json");
var dbLock = new object();
var webhookLog = new List<WebhookLogEntry>();
const int MaxLogEntries = 50;

List<Signal> ReadSignals()
{
    lock (dbLock)
    {
        if (!File.Exists(dbPath)) return new List<Signal>();
        try
        {
            var json = File.ReadAllText(dbPath);
            return JsonSerializer.Deserialize<List<Signal>>(json, jsonOpts) ?? new List<Signal>();
        }
        catch
        {
            return new List<Signal>();
        }
    }
}

void WriteSignals(List<Signal> signals)
{
    lock (dbLock)
    {
        var json = JsonSerializer.Serialize(signals, jsonOpts);
        File.WriteAllText(dbPath, json);
    }
}

void AddLog(string action, string body, object? result, string? error = null)
{
    lock (dbLock)
    {
        webhookLog.Add(new WebhookLogEntry
        {
            Timestamp = DateTime.UtcNow,
            Action = action,
            Body = body,
            Result = result,
            Error = error
        });
        if (webhookLog.Count > MaxLogEntries)
            webhookLog.RemoveAt(0);
    }
}

// ──────────────────────────────────────────────
// Webhook — รับสัญญาณจาก TradingView (โหมดทดสอบ ไม่เปิด MT5)
// ──────────────────────────────────────────────
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
            AddLog("?", body, null, "Invalid JSON payload");
            return Results.BadRequest(new { ok = false, error = "Invalid JSON payload" });
        }

        if (payload.Token != webhookSecret)
        {
            AddLog(payload.Action ?? "?", body, null, "Unauthorized");
            return Results.Json(new { ok = false, error = "Unauthorized" }, statusCode: 401);
        }

        var signals = ReadSignals();
        var action = payload.Action?.ToUpper();

        if (action is "BUY" or "SELL")
        {
            // กันสัญญาณซ้ำจาก signal_id เดิม
            if (!string.IsNullOrWhiteSpace(payload.SignalId) &&
                signals.Any(s => s.SignalId == payload.SignalId))
            {
                var dup = new { ok = true, duplicate = true, message = "Signal already logged", signalId = payload.SignalId };
                AddLog(action, body, dup);
                return Results.Ok(dup);
            }

            var newSignal = new Signal
            {
                Id = !string.IsNullOrWhiteSpace(payload.SignalId)
                    ? payload.SignalId
                    : DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString(),
                SignalId = payload.SignalId ?? "",
                Timestamp = DateTime.UtcNow,
                BarTime = payload.BarTime,
                Timeframe = payload.Timeframe ?? "",
                Action = action,
                Symbol = payload.Symbol ?? "XAUUSD",
                Sl = payload.Sl,
                Tp = payload.Tp,
                Rr = payload.Rr,
                EntryPrice = payload.EntryPrice > 0 ? payload.EntryPrice : 0.0,
                Status = "OPEN",
                Comment = payload.Comment ?? ""
            };
            signals.Add(newSignal);
            WriteSignals(signals);

            var res = new { ok = true, message = $"{action} signal logged", signalId = newSignal.Id, mode = "signal_test" };
            AddLog(action, body, res);
            return Results.Ok(res);
        }

        if (action == "CLOSE_SIGNAL")
        {
            Signal? target = null;

            if (!string.IsNullOrWhiteSpace(payload.SignalId))
            {
                target = signals
                    .Where(s => s.Status == "OPEN" && s.SignalId == payload.SignalId)
                    .OrderByDescending(s => s.Timestamp)
                    .FirstOrDefault();
            }

            target ??= signals
                .Where(s => s.Status == "OPEN" && s.Symbol.Equals(payload.Symbol ?? "XAUUSD", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(s => s.Timestamp)
                .FirstOrDefault();

            if (target == null)
            {
                var err = new { ok = false, error = "No open signals found to close" };
                AddLog(action, body, err);
                return Results.Ok(err);
            }

            target.Status = payload.Result?.ToUpper() == "WIN" ? "WIN" : "LOSS";
            target.ExitPrice = payload.ExitPrice;
            target.Profit = payload.Profit;
            if (target.EntryPrice == 0.0 && payload.EntryPrice > 0)
                target.EntryPrice = payload.EntryPrice;

            WriteSignals(signals);
            var closeRes = new { ok = true, message = $"Signal {target.Id} → {target.Status}", profit = target.Profit, mode = "signal_test" };
            AddLog(action, body, closeRes);
            return Results.Ok(closeRes);
        }

        var bad = new { ok = false, error = $"Unsupported action: {action}" };
        AddLog(action ?? "?", body, bad);
        return Results.BadRequest(bad);
    }
    catch (Exception ex)
    {
        AddLog("ERROR", body, null, ex.Message);
        return Results.Json(new { ok = false, error = ex.Message }, statusCode: 500);
    }
});

// ──────────────────────────────────────────────
// API: Signals & Status (โหมดทดสอบ)
// ──────────────────────────────────────────────
app.MapGet("/api/signals", () => Results.Ok(ReadSignals()));

app.MapPost("/api/signals/clear", () =>
{
    WriteSignals(new List<Signal>());

    // ลบไฟล์เก่าจากเวอร์ชันก่อนหน้า (เก็บใน Temp)
    var legacyPath = Path.Combine(Path.GetTempPath(), "ats_signals_db.json");
    if (File.Exists(legacyPath))
        File.Delete(legacyPath);

    return Results.Ok(new { ok = true, message = "Signal database cleared", dbPath });
});

app.MapGet("/api/webhook/log", () => Results.Ok(webhookLog.OrderByDescending(l => l.Timestamp).Take(20)));

app.MapGet("/api/status", () => Results.Ok(new
{
    ok = true,
    mode = "signal_test",
    mt5_connected = false,
    message = "โหมดทดสอบสัญญาณ — ยังไม่เชื่อม MT5"
}));

app.Run();

public class Signal
{
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("signalId")]
    public string SignalId { get; set; } = string.Empty;

    public DateTime Timestamp { get; set; }

    [JsonPropertyName("barTime")]
    public long BarTime { get; set; }

    public string Timeframe { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
    public string Symbol { get; set; } = string.Empty;
    public double Sl { get; set; }
    public double Tp { get; set; }
    public double Rr { get; set; }

    [JsonPropertyName("entryPrice")]
    public double EntryPrice { get; set; }

    [JsonPropertyName("exitPrice")]
    public double ExitPrice { get; set; }

    public double Profit { get; set; }
    public string Status { get; set; } = "OPEN";
    public string Comment { get; set; } = string.Empty;
}

public class WebhookPayload
{
    public string Token { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
    public string Symbol { get; set; } = string.Empty;

    [JsonPropertyName("signal_id")]
    public string SignalId { get; set; } = string.Empty;

    public double Sl { get; set; }
    public double Tp { get; set; }
    public double Rr { get; set; }

    [JsonPropertyName("entry_price")]
    public double EntryPrice { get; set; }

    [JsonPropertyName("exit_price")]
    public double ExitPrice { get; set; }

    public double Profit { get; set; }
    public string Result { get; set; } = string.Empty;
    public string Comment { get; set; } = string.Empty;
    public string Timeframe { get; set; } = string.Empty;

    [JsonPropertyName("bar_time")]
    public long BarTime { get; set; }
}

public class WebhookLogEntry
{
    public DateTime Timestamp { get; set; }
    public string Action { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public object? Result { get; set; }
    public string? Error { get; set; }
}
