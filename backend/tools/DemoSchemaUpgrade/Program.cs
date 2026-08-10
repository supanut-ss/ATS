using System.Text.Json;
using MySqlConnector;

var backendDirectory = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));
var configPath = Path.Combine(backendDirectory, "appsettings.json");
var v189MigrationPath = Path.Combine(backendDirectory, "sql", "upgrade_demo_trade_analytics_v189.sql");
var v190MigrationPath = Path.Combine(backendDirectory, "sql", "upgrade_demo_trade_analytics_v190.sql");
var logRedactionPath = Path.Combine(backendDirectory, "sql", "redact_legacy_webhook_logs_v189.sql");

using var config = JsonDocument.Parse(await File.ReadAllTextAsync(configPath));
var connectionString = config.RootElement.GetProperty("ConnectionStrings").GetProperty("MySql").GetString();
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException("ConnectionStrings:MySql is missing");

var connectionOptions = new MySqlConnectionStringBuilder(connectionString)
{
    AllowUserVariables = true
};
await using var connection = new MySqlConnection(connectionOptions.ConnectionString);
await connection.OpenAsync();

await using (var checkTable = connection.CreateCommand())
{
    checkTable.CommandText = @"SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='demo_trade_analytics'";
    if (Convert.ToInt32(await checkTable.ExecuteScalarAsync()) != 1)
        throw new InvalidOperationException("demo_trade_analytics does not exist; run create_tables.sql first");
}

// Repair v1.88 one column at a time. This remains resumable if an earlier run
// stopped between ALTER statements.
var requiredColumns = new (string Name, string Definition)[]
{
    ("account_ref", "VARCHAR(60) NOT NULL DEFAULT 'legacy' AFTER `ticket`"),
    ("signal_type", "VARCHAR(30) NOT NULL DEFAULT '' AFTER `action`"),
    ("timeframe", "VARCHAR(10) NOT NULL DEFAULT '' AFTER `signal_type`"),
    ("entry_time", "DATETIME NULL AFTER `timeframe`"),
    ("exit_time", "DATETIME NULL AFTER `entry_time`"),
    ("duration_seconds", "INT NOT NULL DEFAULT 0 AFTER `exit_time`"),
    ("volume", "DOUBLE NOT NULL DEFAULT 0 AFTER `exit_price`"),
    ("initial_sl", "DOUBLE NOT NULL DEFAULT 0 AFTER `volume`"),
    ("initial_tp", "DOUBLE NOT NULL DEFAULT 0 AFTER `initial_sl`"),
    ("commission", "DOUBLE NOT NULL DEFAULT 0 AFTER `profit`"),
    ("swap", "DOUBLE NOT NULL DEFAULT 0 AFTER `commission`"),
    ("net_profit", "DOUBLE NOT NULL DEFAULT 0 AFTER `swap`"),
    ("spread_points", "DOUBLE NOT NULL DEFAULT 0 AFTER `mae`"),
    ("atr", "DOUBLE NOT NULL DEFAULT 0 AFTER `spread_points`"),
    ("market_regime", "VARCHAR(20) NOT NULL DEFAULT '' AFTER `atr`"),
    ("session_name", "VARCHAR(20) NOT NULL DEFAULT '' AFTER `market_regime`"),
    ("entry_hour", "INT NOT NULL DEFAULT 0 AFTER `session_name`"),
    ("loss_streak_before", "INT NOT NULL DEFAULT 0 AFTER `entry_hour`"),
    ("exit_reason", "VARCHAR(40) NOT NULL DEFAULT '' AFTER `loss_streak_before`"),
    ("ea_version", "VARCHAR(20) NOT NULL DEFAULT '' AFTER `exit_reason`"),
    ("settings_hash", "VARCHAR(100) NOT NULL DEFAULT '' AFTER `ea_version`"),
    ("level_price", "DOUBLE NOT NULL DEFAULT 0 AFTER `settings_hash`"),
    ("pivot_time", "DATETIME NULL AFTER `level_price`"),
    ("result", "VARCHAR(20) NOT NULL DEFAULT '' AFTER `pivot_time`"),
    ("updated_at", "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`")
};

foreach (var column in requiredColumns)
    await EnsureColumnAsync(connection, column.Name, column.Definition);

var v189MigrationSql = await File.ReadAllTextAsync(v189MigrationPath);
await using (var migrateV189 = new MySqlCommand(v189MigrationSql, connection) { CommandTimeout = 60 })
    await migrateV189.ExecuteNonQueryAsync();

var v190MigrationSql = await File.ReadAllTextAsync(v190MigrationPath);
await using (var migrateV190 = new MySqlCommand(v190MigrationSql, connection) { CommandTimeout = 60 })
    await migrateV190.ExecuteNonQueryAsync();

await EnsureIndexAsync(connection, "idx_demo_trade_exit_time", "`exit_time`");
await EnsureIndexAsync(connection, "idx_demo_trade_result", "`result`");
await EnsureIndexAsync(connection, "idx_demo_trade_signal_type", "`signal_type`");

var logRedactionSql = await File.ReadAllTextAsync(logRedactionPath);
await using (var redactLogs = new MySqlCommand(logRedactionSql, connection) { CommandTimeout = 60 })
    await redactLogs.ExecuteNonQueryAsync();

await using (var verifyPrimaryKey = connection.CreateCommand())
{
    verifyPrimaryKey.CommandText = @"SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',')
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='demo_trade_analytics' AND INDEX_NAME='PRIMARY'";
    var primaryColumns = Convert.ToString(await verifyPrimaryKey.ExecuteScalarAsync());
    if (!string.Equals(primaryColumns, "account_ref,ticket", StringComparison.Ordinal))
        throw new InvalidOperationException("Demo analytics composite primary key verification failed");
}

var requiredV190Columns = requiredColumns.Select(column => column.Name)
    .Concat(new[] { "broker_utc_offset_seconds", "time_basis", "data_quality" })
    .ToArray();
await using (var verifyColumns = connection.CreateCommand())
{
    verifyColumns.CommandText = @"SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='demo_trade_analytics'
          AND COLUMN_NAME IN (" + string.Join(",", requiredV190Columns.Select((_, index) => $"@column{index}")) + ")";
    for (var index = 0; index < requiredV190Columns.Length; index++)
        verifyColumns.Parameters.AddWithValue($"@column{index}", requiredV190Columns[index]);
    var found = Convert.ToInt32(await verifyColumns.ExecuteScalarAsync());
    if (found != requiredV190Columns.Length)
        throw new InvalidOperationException(
            $"Demo analytics schema verification failed: expected {requiredV190Columns.Length} required columns, found {found}.");
}

Console.WriteLine("Demo analytics schema upgraded to v1.90 and legacy webhook logs redacted. Main trade analytics remained unchanged.");

static async Task EnsureColumnAsync(MySqlConnection connection, string name, string definition)
{
    await using var check = connection.CreateCommand();
    check.CommandText = @"SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='demo_trade_analytics' AND COLUMN_NAME=@name";
    check.Parameters.AddWithValue("@name", name);
    if (Convert.ToInt32(await check.ExecuteScalarAsync()) == 1)
        return;

    await using var alter = connection.CreateCommand();
    alter.CommandText = $"ALTER TABLE `demo_trade_analytics` ADD COLUMN `{name}` {definition}";
    alter.CommandTimeout = 60;
    await alter.ExecuteNonQueryAsync();
    Console.WriteLine($"Added missing demo_trade_analytics.{name}.");
}

static async Task EnsureIndexAsync(MySqlConnection connection, string name, string columns)
{
    await using var check = connection.CreateCommand();
    check.CommandText = @"SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='demo_trade_analytics' AND INDEX_NAME=@name";
    check.Parameters.AddWithValue("@name", name);
    if (Convert.ToInt32(await check.ExecuteScalarAsync()) > 0)
        return;

    await using var create = connection.CreateCommand();
    create.CommandText = $"CREATE INDEX `{name}` ON `demo_trade_analytics` ({columns})";
    create.CommandTimeout = 60;
    await create.ExecuteNonQueryAsync();
    Console.WriteLine($"Added missing index {name}.");
}
