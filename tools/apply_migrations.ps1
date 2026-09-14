param(
    [string]$ConnectionString = $env:SHOUTECH_CONNECTION_STRING,
    [string]$Provider = $(if ($env:SHOUTECH_DB_PROVIDER) { $env:SHOUTECH_DB_PROVIDER } else { "SQLite" })
)

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    throw "Connection string is required. Set SHOUTECH_CONNECTION_STRING or pass -ConnectionString."
}

$env:SHOUTECH_CONNECTION_STRING = $ConnectionString
$env:SHOUTECH_DB_PROVIDER = $Provider
$project = Join-Path $PSScriptRoot "SqlMigrator\SqlMigrator.csproj"
dotnet run --project $project --no-restore
if ($LASTEXITCODE -ne 0) {
    throw "Migration runner failed with exit code $LASTEXITCODE."
}
