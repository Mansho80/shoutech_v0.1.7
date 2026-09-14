$root = 'D:\erp\shoutech_erp_v0.1.6'
$typeRenames = @(
    @('MainWindow', 'MWin'),
    @('DataService', 'DataSvc'),
    @('UserSession', 'UsrSess'),
    @('AppSettings', 'AppSet'),
    @('AppFormats', 'AppFmt'),
    @('UiLocalizer', 'UiLocz'),
    @('LightTheme', 'LtTheme'),
    @('DarkTheme', 'DkTheme')
)
$files = @(
    (Join-Path $root 'cod\app\src'),
    (Join-Path $root 'cfg'),
    (Join-Path $root 'tests')
) | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem -Path $_ -Recurse -Include *.cs,*.xaml -File |
            Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\' }
    }
}
foreach ($file in $files) {
    $content = [IO.File]::ReadAllText($file.FullName)
    $original = $content
    foreach ($pair in $typeRenames) { $content = $content.Replace($pair[0], $pair[1]) }
    if ($content -ne $original) {
        [IO.File]::WriteAllText($file.FullName, $content)
        Write-Host "Updated $($file.Name)"
    }
}
