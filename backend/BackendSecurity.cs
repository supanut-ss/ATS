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
