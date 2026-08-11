using System.Text.Json;
using Microsoft.AspNetCore.Http;

static void Assert(bool condition, string message)
{
    if (!condition)
        throw new InvalidOperationException(message);
}

var nestedSecret = "sensitive-test-value";
var redacted = BackendSecurity.RedactJsonForLog(
    $$"""{"token":"{{nestedSecret}}","nested":{"password":"{{nestedSecret}}"},"safe":"visible"}""");
Assert(!redacted.Contains(nestedSecret, StringComparison.Ordinal), "JSON log redaction leaked a credential");
Assert(redacted.Contains("[REDACTED]", StringComparison.Ordinal), "JSON log redaction marker is missing");
Assert(redacted.Contains("visible", StringComparison.Ordinal), "Non-sensitive log context was removed");
Assert(
    BackendSecurity.RedactJsonForLog("invalid token=sensitive-test-value") == "[unparseable payload omitted]",
    "Invalid payload was persisted instead of omitted");

var context = new DefaultHttpContext();
context.Request.Headers.Authorization = "Bearer read-test-secret";
Assert(
    BackendSecurity.IsRequestAuthorized(context.Request, "read-test-secret", "webhook-test-secret"),
    "Bearer read credential was rejected");
context.Request.Headers.Authorization = "Bearer wrong-test-secret";
Assert(
    !BackendSecurity.IsRequestAuthorized(context.Request, "read-test-secret", "webhook-test-secret"),
    "Invalid read credential was accepted");
context.Request.Headers.Authorization = "";
context.Request.QueryString = new QueryString("?token=read-test-secret");
Assert(
    !BackendSecurity.IsRequestAuthorized(context.Request, "read-test-secret"),
    "Query-string credential must not be accepted or leaked through access logs");
context.Request.QueryString = QueryString.Empty;
context.Request.Headers["X-ATS-Write-Key"] = "write-test-secret";
Assert(
    BackendSecurity.IsRequestAuthorized(context.Request, "write-test-secret"),
    "Dashboard write credential was rejected");

const long entryTime = 1_767_225_600; // 2026-01-01 UTC
var validPayload = new DemoTradeAnalyticsPayload
{
    PositionId = "10001",
    AccountRef = "demo-sr",
    Symbol = "XAUUSD",
    Action = "buy",
    SignalType = "SUPPORT_BUY",
    Timeframe = "PERIOD_M15",
    EntryTime = entryTime,
    ExitTime = entryTime + 3_600,
    DurationSeconds = 3_600,
    EntryPrice = 4_000,
    ExitPrice = 4_010,
    Volume = 0.05,
    InitialSl = 3_990,
    InitialTp = 4_020,
    Profit = 10,
    Commission = -0.25,
    Swap = 0,
    NetProfit = 9.75,
    Mfe = 12,
    Mae = -3,
    SpreadPoints = 25,
    Atr = 8,
    MarketRegime = "TREND",
    SessionName = "LONDON",
    EntryHour = 10,
    LossStreakBefore = 0,
    ExitReason = "TAKE_PROFIT",
    EaVersion = "1.89",
    SettingsHash = "test-settings",
    LevelPrice = 3_999,
    PivotTime = entryTime - 900,
    Result = "win",
    BrokerUtcOffsetSeconds = 7 * 3_600,
    TimeBasis = "broker_server",
    DataQuality = "live_capture"
};

var validationError = DemoTradeAnalyticsValidator.ValidateAndNormalize(
    validPayload,
    1.0,
    DateTimeOffset.FromUnixTimeSeconds(entryTime + 86_400));
Assert(validationError == null, $"Valid analytics payload was rejected: {validationError}");
Assert(validPayload.Action == "BUY" && validPayload.Result == "WIN", "Analytics values were not normalized");

var inconsistentNet = JsonSerializer.Deserialize<DemoTradeAnalyticsPayload>(
    JsonSerializer.Serialize(validPayload))!;
inconsistentNet.NetProfit = 999;
Assert(
    DemoTradeAnalyticsValidator.ValidateAndNormalize(
        inconsistentNet,
        1.0,
        DateTimeOffset.FromUnixTimeSeconds(entryTime + 86_400))?.Contains("net profit", StringComparison.Ordinal) == true,
    "Inconsistent net profit was accepted");

var invalidResult = JsonSerializer.Deserialize<DemoTradeAnalyticsPayload>(
    JsonSerializer.Serialize(validPayload))!;
invalidResult.Result = "LOSS";
Assert(
    DemoTradeAnalyticsValidator.ValidateAndNormalize(
        invalidResult,
        1.0,
        DateTimeOffset.FromUnixTimeSeconds(entryTime + 86_400))?.Contains("result", StringComparison.Ordinal) == true,
    "Result inconsistent with server-computed net profit was accepted");

var nonFinite = JsonSerializer.Deserialize<DemoTradeAnalyticsPayload>(
    JsonSerializer.Serialize(validPayload))!;
nonFinite.Atr = double.PositiveInfinity;
Assert(
    DemoTradeAnalyticsValidator.ValidateAndNormalize(
        nonFinite,
        1.0,
        DateTimeOffset.FromUnixTimeSeconds(entryTime + 86_400)) != null,
    "Non-finite analytics value was accepted");

var backendDirectory = Path.GetFullPath(Path.Combine(
    AppContext.BaseDirectory,
    "..", "..", "..", "..", ".."));
var programSource = await File.ReadAllTextAsync(Path.Combine(backendDirectory, "Program.cs"));
Assert(!programSource.Contains("AllowAnyOrigin", StringComparison.Ordinal), "Unrestricted CORS remains enabled");
Assert(!programSource.Contains("?? \"ats_sec_", StringComparison.Ordinal), "Hard-coded webhook fallback remains");
Assert(
    !programSource.Contains("compatibilityFallback", StringComparison.Ordinal),
    "Webhook credentials can still fall back to dashboard read/write authorization");
Assert(
    programSource.Contains("RequireIndependentSecret(\"AdminSettings:ReadSecret\"", StringComparison.Ordinal) &&
    programSource.Contains("RequireIndependentSecret(\"AdminSettings:WriteSecret\"", StringComparison.Ordinal),
    "Main dashboard read/write secrets are not required at startup");
foreach (var route in new[]
{
    "api/signals/clear", "api/connect", "api/disconnect", "api/trade",
    "api/close/{ticket}", "api/close-all", "api/modify/{ticket}"
})
{
    var routeIndex = programSource.IndexOf($"\"/{route}\"", StringComparison.Ordinal);
    Assert(routeIndex >= 0, $"Protected mutation route /{route} is missing");
    var routeWindow = programSource.Substring(routeIndex, Math.Min(650, programSource.Length - routeIndex));
    Assert(
        routeWindow.Contains("HasActiveWriteAccess", StringComparison.Ordinal),
        $"Mutation route /{route} does not enforce dashboard write authorization");
}

var schema = await File.ReadAllTextAsync(Path.Combine(backendDirectory, "sql", "create_tables.sql"));
Assert(
    schema.Contains("PRIMARY KEY (`account_ref`, `ticket`)", StringComparison.Ordinal),
    "Demo analytics composite idempotency key is missing");
Assert(
    schema.Contains("`broker_utc_offset_seconds`", StringComparison.Ordinal) &&
    schema.Contains("`data_quality`", StringComparison.Ordinal),
    "Demo analytics time/data-quality metadata columns are missing");

var repositoryDirectory = Directory.GetParent(backendDirectory)?.FullName
    ?? throw new InvalidOperationException("Repository root could not be resolved");
var webhookGuide = await File.ReadAllTextAsync(Path.Combine(
    repositoryDirectory, "src", "components", "WebhookGuide.jsx"));
Assert(
    webhookGuide.Contains("param: 'InpAuthToken', defaultVal: 'ตั้งค่าใน MT5 Inputs เท่านั้น'", StringComparison.Ordinal),
    "Webhook guide does not use the safe MT5-input-only credential instruction");

foreach (var scanRoot in new[]
{
    Path.Combine(repositoryDirectory, "src"),
    Path.Combine(backendDirectory, "wwwroot")
})
{
    if (!Directory.Exists(scanRoot))
        continue;
    foreach (var file in Directory.EnumerateFiles(scanRoot, "*", SearchOption.AllDirectories)
        .Where(path => path.EndsWith(".js", StringComparison.OrdinalIgnoreCase) ||
                       path.EndsWith(".jsx", StringComparison.OrdinalIgnoreCase) ||
                       path.EndsWith(".html", StringComparison.OrdinalIgnoreCase)))
    {
        var text = await File.ReadAllTextAsync(file);
        Assert(
            !text.Contains("ats_sec_", StringComparison.Ordinal) &&
            !text.Contains("ats_demo_sec_", StringComparison.Ordinal),
            $"Credential-shaped literal remains in web asset: {Path.GetRelativePath(repositoryDirectory, file)}");
    }
}

Console.WriteLine("Backend security checks passed.");
