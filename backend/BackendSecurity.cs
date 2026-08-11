using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

public static class BackendSecurity
{
    private const string RedactedValue = "[REDACTED]";
    private const string OmittedValue = "[unparseable payload omitted]";
    private static readonly HashSet<string> SensitivePropertyNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "token",
        "secret",
        "password",
        "api_key",
        "apikey",
        "authorization"
    };

    public static bool IsRequestAuthorized(HttpRequest request, params string?[] acceptedSecrets)
    {
        var supplied = GetRequestCredential(request);
        if (string.IsNullOrWhiteSpace(supplied))
            return false;

        foreach (var secret in acceptedSecrets)
        {
            if (!string.IsNullOrWhiteSpace(secret) && FixedTimeEquals(supplied, secret))
                return true;
        }

        return false;
    }

    public static bool FixedTimeEquals(string? supplied, string? expected)
    {
        if (string.IsNullOrEmpty(supplied) || string.IsNullOrEmpty(expected))
            return false;
        var suppliedHash = SHA256.HashData(Encoding.UTF8.GetBytes(supplied));
        var expectedHash = SHA256.HashData(Encoding.UTF8.GetBytes(expected));
        return CryptographicOperations.FixedTimeEquals(suppliedHash, expectedHash);
    }

    public static string RedactJsonForLog(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return string.Empty;

        try
        {
            using var document = JsonDocument.Parse(json);
            using var output = new MemoryStream();
            using (var writer = new Utf8JsonWriter(output))
                WriteRedacted(document.RootElement, writer);
            return Encoding.UTF8.GetString(output.ToArray());
        }
        catch (JsonException)
        {
            // Invalid input can still contain credentials. Never persist it verbatim.
            return OmittedValue;
        }
    }

    public static string LimitLogValue(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value))
            return string.Empty;
        return value.Length <= maxLength ? value : value[..maxLength];
    }

    private static string? GetRequestCredential(HttpRequest request)
    {
        var authorization = request.Headers.Authorization.ToString();
        const string bearerPrefix = "Bearer ";
        if (authorization.StartsWith(bearerPrefix, StringComparison.OrdinalIgnoreCase))
            return authorization[bearerPrefix.Length..].Trim();

        var writeKey = request.Headers["X-ATS-Write-Key"].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(writeKey))
            return writeKey.Trim();

        var apiKey = request.Headers["X-ATS-Read-Key"].FirstOrDefault();
        return string.IsNullOrWhiteSpace(apiKey) ? null : apiKey.Trim();
    }

    private static void WriteRedacted(JsonElement element, Utf8JsonWriter writer)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in element.EnumerateObject())
                {
                    writer.WritePropertyName(property.Name);
                    if (SensitivePropertyNames.Contains(property.Name))
                        writer.WriteStringValue(RedactedValue);
                    else
                        WriteRedacted(property.Value, writer);
                }
                writer.WriteEndObject();
                break;
            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (var item in element.EnumerateArray())
                    WriteRedacted(item, writer);
                writer.WriteEndArray();
                break;
            default:
                element.WriteTo(writer);
                break;
        }
    }
}

public static class DemoTradeAnalyticsValidator
{
    private const long MinUnixTimestamp = 946684800; // 2000-01-01 UTC
    private const double MaxMoneyMagnitude = 1_000_000_000d;
    private const double MaxPrice = 10_000_000d;
    private const double NetTolerance = 0.02d;

    public static string? ValidateAndNormalize(
        DemoTradeAnalyticsPayload payload,
        double breakEvenThresholdMoney,
        DateTimeOffset? now = null)
    {
        payload.PositionId = NormalizeText(payload.PositionId);
        payload.AccountRef = NormalizeText(payload.AccountRef);
        payload.Symbol = NormalizeText(payload.Symbol);
        payload.Action = NormalizeText(payload.Action).ToUpperInvariant();
        payload.SignalType = NormalizeText(payload.SignalType);
        payload.Timeframe = NormalizeText(payload.Timeframe);
        payload.MarketRegime = NormalizeText(payload.MarketRegime);
        payload.SessionName = NormalizeText(payload.SessionName);
        payload.ExitReason = NormalizeText(payload.ExitReason);
        payload.EaVersion = NormalizeText(payload.EaVersion);
        payload.SettingsHash = NormalizeText(payload.SettingsHash);
        payload.TimeBasis = NormalizeText(payload.TimeBasis).ToUpperInvariant();
        payload.DataQuality = NormalizeText(payload.DataQuality).ToUpperInvariant();
        payload.Result = NormalizeText(payload.Result).ToUpperInvariant();

        if (!ValidText(payload.PositionId, 30, required: true) ||
            !ValidText(payload.AccountRef, 60, required: true) ||
            !ValidText(payload.Symbol, 20, required: true) ||
            !ValidText(payload.SignalType, 30) ||
            !ValidText(payload.Timeframe, 10) ||
            !ValidText(payload.MarketRegime, 20) ||
            !ValidText(payload.SessionName, 20) ||
            !ValidText(payload.ExitReason, 40) ||
            !ValidText(payload.EaVersion, 20) ||
            !ValidText(payload.SettingsHash, 100) ||
            !ValidText(payload.TimeBasis, 20, required: true) ||
            !ValidText(payload.DataQuality, 30, required: true))
            return "invalid trade identity or text field";

        if (payload.Action is not ("BUY" or "SELL") ||
            payload.Result is not ("WIN" or "LOSS" or "BREAK_EVEN"))
            return "invalid trade action or result";

        var maxTimestamp = (now ?? DateTimeOffset.UtcNow).AddDays(1).ToUnixTimeSeconds();
        if (!ValidTimestamp(payload.EntryTime, maxTimestamp) ||
            !ValidTimestamp(payload.ExitTime, maxTimestamp) ||
            !ValidTimestamp(payload.PivotTime, maxTimestamp) ||
            payload.ExitTime < payload.EntryTime ||
            payload.PivotTime > payload.EntryTime)
            return "invalid trade timestamps";

        var computedDuration = payload.ExitTime - payload.EntryTime;
        if (computedDuration > int.MaxValue || payload.DurationSeconds != computedDuration)
            return "duration does not match entry and exit timestamps";

        if (!FiniteBetween(payload.EntryPrice, double.Epsilon, MaxPrice) ||
            !FiniteBetween(payload.ExitPrice, double.Epsilon, MaxPrice) ||
            !FiniteBetween(payload.Volume, double.Epsilon, 10_000d) ||
            !FiniteBetween(payload.InitialSl, 0d, MaxPrice) ||
            !FiniteBetween(payload.InitialTp, 0d, MaxPrice) ||
            !FiniteBetween(payload.LevelPrice, 0d, MaxPrice) ||
            !FiniteBetween(payload.SpreadPoints, 0d, MaxPrice) ||
            !FiniteBetween(payload.Atr, 0d, MaxPrice) ||
            !FiniteBetween(payload.Profit, -MaxMoneyMagnitude, MaxMoneyMagnitude) ||
            !FiniteBetween(payload.Commission, -MaxMoneyMagnitude, MaxMoneyMagnitude) ||
            !FiniteBetween(payload.Swap, -MaxMoneyMagnitude, MaxMoneyMagnitude) ||
            !FiniteBetween(payload.NetProfit, -MaxMoneyMagnitude, MaxMoneyMagnitude) ||
            // MFE (max favourable excursion) is always >= 0; a trade that never
            // moved into profit remains at its initial value of 0.
            !FiniteBetween(payload.Mfe, 0d, MaxMoneyMagnitude) ||
            // MAE (max adverse excursion) is always <= 0; a trade that was
            // profitable from the first tick has MAE = 0.0, so we allow [−Max, 0].
            !FiniteBetween(payload.Mae, -MaxMoneyMagnitude, 0d))
            return "invalid numeric trade value";

        if (payload.EntryHour is < 0 or > 23 ||
            payload.LossStreakBefore is < 0 or > 100_000 ||
            payload.BrokerUtcOffsetSeconds is < -86_400 or > 86_400 ||
            payload.TimeBasis is not ("BROKER_SERVER" or "UTC") ||
            !double.IsFinite(breakEvenThresholdMoney) ||
            breakEvenThresholdMoney is < 0d or > 1_000_000d)
            return "invalid trade counter or analytics configuration";

        var computedNet = Math.Round(
            payload.Profit + payload.Commission + payload.Swap,
            2,
            MidpointRounding.AwayFromZero);
        if (Math.Abs(payload.NetProfit - computedNet) > NetTolerance)
            return "net profit does not match profit, commission, and swap";

        var computedResult = computedNet > breakEvenThresholdMoney
            ? "WIN"
            : computedNet < -breakEvenThresholdMoney
                ? "LOSS"
                : "BREAK_EVEN";
        if (!string.Equals(payload.Result, computedResult, StringComparison.Ordinal))
            return "result does not match net profit";

        // Persist canonical server-computed values rather than client-derived copies.
        payload.DurationSeconds = checked((int)computedDuration);
        payload.NetProfit = computedNet;
        payload.Result = computedResult;
        return null;
    }

    private static bool ValidTimestamp(long timestamp, long maxTimestamp) =>
        timestamp >= MinUnixTimestamp && timestamp <= maxTimestamp;

    private static bool FiniteBetween(double value, double min, double max) =>
        double.IsFinite(value) && value >= min && value <= max;

    private static bool ValidText(string value, int maxLength, bool required = false) =>
        (!required || value.Length > 0) &&
        value.Length <= maxLength &&
        !value.Any(char.IsControl);

    private static string NormalizeText(string? value) => value?.Trim() ?? string.Empty;
}
