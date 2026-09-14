# Differentiate similar short filenames (+1–2 chars on the clearer name).
$ErrorActionPreference = 'Stop'
$root = 'D:\erp\shoutech_erp_v0.1.6'
$app  = Join-Path $root 'cod\app\src'

$fileRenames = @(
    @('ViewModels\MShlVM.cs', 'ViewModels\MainShVM.cs'),
    @('ViewModels\MWnVM.cs', 'ViewModels\MainWnVM.cs'),
    @('ViewModels\MdWsVM.cs', 'ViewModels\ModWsVM.cs'),
    @('ViewModels\LogWVM.cs', 'ViewModels\LogWinVM.cs'),
    @('Views\Modules\MdWsVw.xaml', 'Views\Modules\ModWsVw.xaml'),
    @('Views\Modules\MdWsVw.xaml.cs', 'Views\Modules\ModWsVw.xaml.cs'),
    @('Configuration\AppSet.cs', 'Configuration\AppSetng.cs'),
    @('Configuration\AppCfgS.cs', 'Configuration\AppCfgSvc.cs'),
    @('Configuration\AppPref.cs', 'Configuration\AppPrefs.cs'),
    @('Services\AuthSvc.cs', 'Services\AuthServ.cs'),
    @('Services\IAuthSv.cs', 'Services\IAuthSvc.cs'),
    @('Localization\LocProp.cs', 'Localization\LocProps.cs'),
    @('Localization\UiLocz.cs', 'Localization\UiLoczr.cs'),
    @('Services\LangDir.cs', 'Services\LangDirSv.cs'),
    @('Converters\LangFlw.cs', 'Converters\LangFlwCv.cs'),
    @('Services\UsrSess.cs', 'Services\UsrSession.cs'),
    @('Services\UsrAccLv.cs', 'Services\UsrAccLvl.cs'),
    @('Services\Online\DevInf.cs', 'Services\Online\DevInfoSv.cs'),
    @('Services\Online\IDevInf.cs', 'Services\Online\IDevInfoSv.cs'),
    @('Services\Online\LicSvc.cs', 'Services\Online\LicenSvc.cs'),
    @('Services\Online\ILicSvc.cs', 'Services\Online\ILicenSvc.cs'),
    @('Services\LogSvc.cs', 'Services\LogServ.cs'),
    @('Services\Online\ConnSvc.cs', 'Services\Online\ConnServ.cs'),
    @('Services\Online\IConnSv.cs', 'Services\Online\IConnSvc.cs'),
    @('Services\Online\SyncSvc.cs', 'Services\Online\SyncServ.cs'),
    @('Services\Online\ISyncSv.cs', 'Services\Online\ISyncSvc.cs'),
    @('Services\NavSvc.cs', 'Services\NavServ.cs'),
    @('Services\PermSvc.cs', 'Services\PermServ.cs'),
    @('Services\BkpSvc.cs', 'Services\BkpServ.cs'),
    @('Services\DataSvc.cs', 'Services\DataServ.cs'),
    @('Services\ThmSvc.cs', 'Services\ThmServ.cs'),
    @('Services\CoRegSv.cs', 'Services\CoRegSvc.cs'),
    @('Services\Online\OnlCrd.cs', 'Services\Online\OnlCoord.cs'),
    @('Services\Online\IOnlCrd.cs', 'Services\Online\IOnlCoord.cs'),
    @('Navigation\RibModM.cs', 'Navigation\RibModMap.cs'),
    @('Services\ShlChrH.cs', 'Services\ShlChrHlpr.cs'),
    @('ViewModels\BseVM.cs', 'ViewModels\BaseVM.cs'),
    @('Common\AppFmt.cs', 'Common\AppFormat.cs'),
    @('Common\JsonDef.cs', 'Common\JsonDefs.cs'),
    @('Common\StatBar.cs', 'Common\StatBarEn.cs')
)

foreach ($pair in $fileRenames) {
    $from = Join-Path $app $pair[0]
    $to   = Join-Path $app $pair[1]
    if (-not (Test-Path $from)) { Write-Warning "Skip: $($pair[0])"; continue }
    Move-Item -LiteralPath $from -Destination $to -Force
    Write-Host "$($pair[0]) -> $($pair[1])"
}

# Longest-first type renames
$typeRenames = @(
    @('InverseBoolToVisibilityConverter', 'InvBVis'),
    @('LanguageToFlowDirectionConverter', 'LangFlwCv'),
    @('LanguageDirectionService', 'LangDirSv'),
    @('LocalizationProperties', 'LocProps'),
    @('SqlCompanyRegistryService', 'CoRegSvc'),
    @('ICompanyRegistryService', 'ICoRegSvc'),
    @('OnlineServicesCoordinator', 'OnlCoord'),
    @('IOnlineServicesCoordinator', 'IOnlCoord'),
    @('ModuleWorkspaceViewModel', 'ModWsVM'),
    @('ModuleWorkspaceView', 'ModWsVw'),
    @('MainShellViewModel', 'MainShVM'),
    @('MainWindowViewModel', 'MainWnVM'),
    @('LogWinViewModel', 'LogWinVM'),
    @('DeviceInfoService', 'DevInfoSv'),
    @('IDeviceInfoService', 'IDevInfoSv'),
    @('ConnectivityService', 'ConnServ'),
    @('IConnectivityService', 'IConnSvc'),
    @('LocalizationService', 'LocSvc'),
    @('ILocalizationService', 'ILocSvc'),
    @('AppPreferencesService', 'AppPrefsSvc'),
    @('AppPreferences', 'AppPrefs'),
    @('AppConfigService', 'AppCfgSvc'),
    @('RibbonModuleMapper', 'RibModMap'),
    @('PermissionService', 'PermServ'),
    @('IPermissionService', 'IPermSvc'),
    @('NavigationService', 'NavServ'),
    @('INavigationService', 'INavSvc'),
    @('LoggingService', 'LogServ'),
    @('ILoggingService', 'ILogSvc'),
    @('ShellChromeHelper', 'ShlChrHlpr'),
    @('UserAccessLevel', 'UsrAccLvl'),
    @('IBackupService', 'IBkpSvc'),
    @('BackupService', 'BkpServ'),
    @('BaseViewModel', 'BaseVM'),
    @('IAuthService', 'IAuthSvc'),
    @('AuthService', 'AuthServ'),
    @('ThemeService', 'ThmServ'),
    @('IThemeService', 'IThmSvc'),
    @('DataService', 'DataServ'),
    @('SyncService', 'SyncServ'),
    @('LicenseService', 'LicenSvc'),
    @('ILicenseService', 'ILicenSvc'),
    @('ISyncService', 'ISyncSvc'),
    @('AppSettings', 'AppSetng'),
    @('AppFormats', 'AppFormat'),
    @('JsonDefaults', 'JsonDefs'),
    @('UiLocalizer', 'UiLoczr'),
    @('UserSession', 'UsrSession'),
    @('MShlVM', 'MainShVM'),
    @('MWnVM', 'MainWnVM'),
    @('MdWsVM', 'ModWsVM'),
    @('MdWsVw', 'ModWsVw'),
    @('LogWVM', 'LogWinVM'),
    @('BseVM', 'BaseVM'),
    @('StatBar', 'StatBarEn'),
    @('LangFlw', 'LangFlwCv'),
    @('LangDir', 'LangDirSv'),
    @('LocProp', 'LocProps'),
    @('UiLocz', 'UiLoczr'),
    @('AppSet', 'AppSetng'),
    @('AppCfgS', 'AppCfgSvc'),
    @('AppPref', 'AppPrefs'),
    @('AppFmt', 'AppFormat'),
    @('JsonDef', 'JsonDefs'),
    @('AuthSvc', 'AuthServ'),
    @('IAuthSv', 'IAuthSvc'),
    @('DevInf', 'DevInfoSv'),
    @('IDevInf', 'IDevInfoSv'),
    @('LicSvc', 'LicenSvc'),
    @('ILicSvc', 'ILicenSvc'),
    @('LogSvc', 'LogServ'),
    @('ConnSvc', 'ConnServ'),
    @('IConnSv', 'IConnSvc'),
    @('SyncSvc', 'SyncServ'),
    @('ISyncSv', 'ISyncSvc'),
    @('NavSvc', 'NavServ'),
    @('PermSvc', 'PermServ'),
    @('BkpSvc', 'BkpServ'),
    @('DataSvc', 'DataServ'),
    @('ThmSvc', 'ThmServ'),
    @('CoRegSv', 'CoRegSvc'),
    @('OnlCrd', 'OnlCoord'),
    @('IOnlCrd', 'IOnlCoord'),
    @('RibModM', 'RibModMap'),
    @('ShlChrH', 'ShlChrHlpr'),
    @('UsrSess', 'UsrSession'),
    @('UsrAccLv', 'UsrAccLvl')
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
    foreach ($pair in $typeRenames) { $content = $content.Replace($pair[0], $pair[1]) }
    if ($content -ne $original) {
        [IO.File]::WriteAllText($file.FullName, $content)
        Write-Host "Updated $($file.Name)"
    }
}

Write-Host 'Done.'
