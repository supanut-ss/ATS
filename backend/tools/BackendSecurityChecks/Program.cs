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

var backendDirectory = Path.GetFullPath(Path.Combine(
    AppContext.BaseDirectory,
    "..", "..", "..", "..", ".."));
var programSource = await File.ReadAllTextAsync(Path.Combine(backendDirectory, "Program.cs"));
Assert(!programSource.Contains("AllowAnyOrigin", StringComparison.Ordinal), "Unrestricted CORS remains enabled");
Assert(!programSource.Contains("?? \"ats_sec_", StringComparison.Ordinal), "Hard-coded webhook fallback remains");
Assert(
    programSource.Contains("RequireIndependentSecret(\"AdminSettings:ReadSecret\"", StringComparison.Ordinal) &&
    programSource.Contains("RequireIndependentSecret(\"AdminSettings:WriteSecret\"", StringComparison.Ordinal),
    "Dashboard read/write secrets are not required at startup");

foreach (var route in new[]
{
    "api/signals/clear", "api/trade", "api/close/{ticket}",
    "api/close-all", "api/modify/{ticket}"
})
{
    var routeIndex = programSource.IndexOf($"\"/{route}\"", StringComparison.Ordinal);
    Assert(routeIndex >= 0, $"Protected mutation route /{route} is missing");
    var routeWindow = programSource.Substring(routeIndex, Math.Min(650, programSource.Length - routeIndex));
    Assert(
        routeWindow.Contains("HasActiveWriteAccess", StringComparison.Ordinal),
        $"Mutation route /{route} does not enforce dashboard write authorization");
}

var repositoryDirectory = Directory.GetParent(backendDirectory)?.FullName
    ?? throw new InvalidOperationException("Repository root could not be resolved");
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
            !text.Contains("ats_sec_", StringComparison.Ordinal),
            $"Credential-shaped literal remains in web asset: {Path.GetRelativePath(repositoryDirectory, file)}");
    }
}

Console.WriteLine("Backend security checks passed.");
