# Shorten long source filenames (6-7 chars) and matching type names.
$ErrorActionPreference = 'Stop'
$root = 'D:\erp\shoutech_erp_v0.1.6'
$app  = Join-Path $root 'cod\app\src'

# --- file renames (relative to $app unless noted) ---
$fileRenames = @(
    @('ViewModels\MainShellViewModel.cs', 'ViewModels\MShlVM.cs'),
    @('ViewModels\MainWindowViewModel.cs', 'ViewModels\MWnVM.cs'),
    @('ViewModels\ModuleWorkspaceViewModel.cs', 'ViewModels\MdWsVM.cs'),
    @('ViewModels\LogWinViewModel.cs', 'ViewModels\LogWVM.cs'),
    @('ViewModels\BaseViewModel.cs', 'ViewModels\BseVM.cs'),
    @('Views\SplashWindow.xaml', 'Views\SplWin.xaml'),
    @('Views\SplashWindow.xaml.cs', 'Views\SplWin.xaml.cs'),
    @('Views\SetupWizardWindow.xaml', 'Views\StpWiz.xaml'),
    @('Views\SetupWizardWindow.xaml.cs', 'Views\StpWiz.xaml.cs'),
    @('Views\Modules\ModuleWorkspaceView.xaml', 'Views\Modules\MdWsVw.xaml'),
    @('Views\Modules\ModuleWorkspaceView.xaml.cs', 'Views\Modules\MdWsVw.xaml.cs'),
    @('Views\Modules\DashboardView.xaml', 'Views\Modules\DashVw.xaml'),
    @('Views\Modules\DashboardView.xaml.cs', 'Views\Modules\DashVw.xaml.cs'),
    @('Services\PermissionService.cs', 'Services\PermSvc.cs'),
    @('Services\NavigationService.cs', 'Services\NavSvc.cs'),
    @('Services\LoggingService.cs', 'Services\LogSvc.cs'),
    @('Services\ShellChromeHelper.cs', 'Services\ShlChrH.cs'),
    @('Services\LanguageDirectionService.cs', 'Services\LangDir.cs'),
    @('Services\CompanyRegistryService.cs', 'Services\CoRegSv.cs'),
    @('Services\AppServiceHost.cs', 'Services\AppHost.cs'),
    @('Services\BackupService.cs', 'Services\BkpSvc.cs'),
    @('Services\AuthService.cs', 'Services\AuthSvc.cs'),
    @('Services\ThemeService.cs', 'Services\ThmSvc.cs'),
    @('Services\ILocalizationService.cs', 'Services\ILocSvc.cs'),
    @('Services\IAuthService.cs', 'Services\IAuthSv.cs'),
    @('Services\IBackupService.cs', 'Services\IBkpSvc.cs'),
    @('Services\UserAccessLevel.cs', 'Services\UsrAccLv.cs'),
    @('Services\Online\DeviceInfoService.cs', 'Services\Online\DevInf.cs'),
    @('Services\Online\LicenseService.cs', 'Services\Online\LicSvc.cs'),
    @('Services\Online\ConnectivityService.cs', 'Services\Online\ConnSvc.cs'),
    @('Services\Online\OnlineServicesCoordinator.cs', 'Services\Online\OnlCrd.cs'),
    @('Services\Online\IOnlineServicesCoordinator.cs', 'Services\Online\IOnlCrd.cs'),
    @('Services\Online\ILicenseService.cs', 'Services\Online\ILicSvc.cs'),
    @('Services\Online\IConnectivityService.cs', 'Services\Online\IConnSv.cs'),
    @('Services\Online\IDeviceInfoService.cs', 'Services\Online\IDevInf.cs'),
    @('Services\Online\SyncService.cs', 'Services\Online\SyncSvc.cs'),
    @('Configuration\AppConfigService.cs', 'Configuration\AppCfgS.cs'),
    @('Configuration\AppPreferences.cs', 'Configuration\AppPref.cs'),
    @('Common\JsonDefaults.cs', 'Common\JsonDef.cs'),
    @('Themes\ShellMenuStyles.xaml', 'Themes\ShMenu.xaml'),
    @('Themes\ShellRibbonStyles.xaml', 'Themes\ShRibn.xaml'),
    @('Converters\BoolToVisibilityConverter.cs', 'Converters\BoolVis.cs'),
    @('Converters\LanguageToFlowDirectionConverter.cs', 'Converters\LangFlw.cs'),
    @('Localization\LocalizationProperties.cs', 'Localization\LocProp.cs'),
    @('Navigation\RibbonModuleMapper.cs', 'Navigation\RibModM.cs')
)

foreach ($pair in $fileRenames) {
    $from = Join-Path $app $pair[0]
    $to   = Join-Path $app $pair[1]
    if (-not (Test-Path $from)) { Write-Warning "Skip missing: $($pair[0])"; continue }
    $dir = Split-Path $to -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Move-Item -LiteralPath $from -Destination $to -Force
    Write-Host "Renamed $($pair[0]) -> $($pair[1])"
}

# --- type / URI renames (longest first) ---
$typeRenames = @(
    @('InverseBoolToVisibilityConverter', 'InvBVis'),
    @('LanguageToFlowDirectionConverter', 'LangFlw'),
    @('OnlineServicesCoordinator', 'OnlCrd'),
    @('IOnlineServicesCoordinator', 'IOnlCrd'),
    @('ModuleWorkspaceViewModel', 'MdWsVM'),
    @('ModuleWorkspaceView', 'MdWsVw'),
    @('LanguageDirectionService', 'LangDir'),
    @('LocalizationProperties', 'LocProp'),
    @('BoolToVisibilityConverter', 'BoolVis'),
    @('NullToVisibilityConverter', 'NullVis'),
    @('SetupWizardWindow', 'StpWiz'),
    @('MainShellViewModel', 'MShlVM'),
    @('MainWindowViewModel', 'MWnVM'),
    @('SqlCompanyRegistryService', 'CoRegSv'),
    @('ICompanyRegistryService', 'ICoRegSv'),
    @('IConnectivityService', 'IConnSv'),
    @('ConnectivityService', 'ConnSvc'),
    @('LocalizationService', 'LocSvc'),
    @('ILocalizationService', 'ILocSvc'),
    @('AppPreferencesService', 'AppPrefSvc'),
    @('InverseBooleanConverter', 'InvBool'),
    @('RibbonModuleMapper', 'RibModM'),
    @('PermissionService', 'PermSvc'),
    @('IPermissionService', 'IPermSvc'),
    @('NavigationService', 'NavSvc'),
    @('INavigationService', 'INavSvc'),
    @('LogWinViewModel', 'LogWVM'),
    @('IDeviceInfoService', 'IDevInf'),
    @('DeviceInfoService', 'DevInf'),
    @('ShellChromeHelper', 'ShlChrH'),
    @('AppConfigService', 'AppCfgS'),
    @('DashboardView', 'DashVw'),
    @('LoggingService', 'LogSvc'),
    @('ILoggingService', 'ILogSvc'),
    @('SplashWindow', 'SplWin'),
    @('AppServiceHost', 'AppHost'),
    @('ILicenseService', 'ILicSvc'),
    @('LicenseService', 'LicSvc'),
    @('UserAccessLevel', 'UsrAccLv'),
    @('IBackupService', 'IBkpSvc'),
    @('BackupService', 'BkpSvc'),
    @('AppPreferences', 'AppPref'),
    @('BaseViewModel', 'BseVM'),
    @('IAuthService', 'IAuthSv'),
    @('AuthService', 'AuthSvc'),
    @('ThemeService', 'ThmSvc'),
    @('IThemeService', 'IThmSvc'),
    @('JsonDefaults', 'JsonDef'),
    @('SyncService', 'SyncSvc')
)

$uriRenames = @(
    @('ShellMenuStyles.xaml', 'ShMenu.xaml'),
    @('ShellRibbonStyles.xaml', 'ShRibn.xaml')
)

$searchRoots = @(
    (Join-Path $root 'cod\app\src'),
    (Join-Path $root 'cfg'),
    (Join-Path $root 'tests')
)

$files = foreach ($sr in $searchRoots) {
    if (Test-Path $sr) {
        Get-ChildItem -Path $sr -Recurse -Include *.cs,*.xaml -File |
            Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\' }
    }
}

foreach ($file in $files) {
    $content = [IO.File]::ReadAllText($file.FullName)
    $original = $content
    foreach ($pair in $typeRenames) {
        $content = $content.Replace($pair[0], $pair[1])
    }
    foreach ($pair in $uriRenames) {
        $content = $content.Replace($pair[0], $pair[1])
    }
    if ($content -ne $original) {
        [IO.File]::WriteAllText($file.FullName, $content)
        Write-Host "Updated $($file.FullName)"
    }
}

Write-Host 'Done.'

# --- batch 2: remaining long names ---
$fileRenames2 = @(
    @('Views\MainWindow.xaml', 'Views\MWin.xaml'),
    @('Views\MainWindow.xaml.cs', 'Views\MWin.xaml.cs'),
    @('Services\DataService.cs', 'Services\DataSvc.cs'),
    @('Services\UserSession.cs', 'Services\UsrSess.cs'),
    @('Services\Online\ISyncService.cs', 'Services\Online\ISyncSv.cs'),
    @('Configuration\AppSettings.cs', 'Configuration\AppSet.cs'),
    @('Common\AppFormats.cs', 'Common\AppFmt.cs'),
    @('Localization\UiLocalizer.cs', 'Localization\UiLocz.cs'),
    @('Themes\LightTheme.xaml', 'Themes\LtTheme.xaml'),
    @('Themes\DarkTheme.xaml', 'Themes\DkTheme.xaml')
)

$typeRenames2 = @(
    @('MainWindow', 'MWin'),
    @('DataService', 'DataSvc'),
    @('UserSession', 'UsrSess'),
    @('AppSettings', 'AppSet'),
    @('AppFormats', 'AppFmt'),
    @('UiLocalizer', 'UiLocz'),
    @('LightTheme', 'LtTheme'),
    @('DarkTheme', 'DkTheme')
)

foreach ($pair in $typeRenames2) {
    foreach ($file in $files) {
        if (-not (Test-Path $file.FullName)) { continue }
        $content = [IO.File]::ReadAllText($file.FullName)
        $updated = $content.Replace($pair[0], $pair[1])
        if ($updated -ne $content) {
            [IO.File]::WriteAllText($file.FullName, $updated)
            Write-Host "Batch2 updated $($file.FullName)"
        }
    }
}
