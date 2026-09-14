# ShouTech ERP — File Abbreviation Map

مرجع يربط **أسماء الملفات المختصرة** الحالية في المشروع ب**أسمائها الطويلة الأصلية** (قبل الاختصار).

> **قاعدة التسمية:** 6–9 أحرف تقريباً، مع لاحقة دلالية عند التشابه:
> `VM` = ViewModel · `Vw` = View · `Svc`/`Serv` = Service · `Cv` = Converter · `Sv` = Service/helper

---

## تطبيق WPF — `cod/app/src`

### نقطة الدخول

| ملف مختصر | اسم طويل / أصلي | Class / Namespace |
|-----------|-----------------|-------------------|
| `App.xaml` | Application entry | `ShouTech.App.App` |
| `App.xaml.cs` | Application code-behind | — |

### ViewModels — `ViewModels/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `MainShVM.cs` | `MainShellViewModel.cs` | `MainShVM` |
| `MainWnVM.cs` | `MainWindowViewModel.cs` (legacy) | `MainWnVM` |
| `ModWsVM.cs` | `ModuleWorkspaceViewModel.cs` | `ModWsVM` |
| `LogWinVM.cs` | `LogWinViewModel.cs` | `LogWinVM` |
| `BaseVM.cs` | `BaseViewModel.cs` | `BaseVM` |

### Views — `Views/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `MWin.xaml` (+ `.cs`) | `MainWindow.xaml` | `MWin` |
| `LogWin.xaml` (+ `.cs`) | Login window (كان مختصراً من البداية) | `LogWin` |
| `ComWin.xaml` (+ `.cs`) | Company selection window | `ComWin` |
| `SplWin.xaml` (+ `.cs`) | `SplashWindow.xaml` | `SplWin` |
| `StpWiz.xaml` (+ `.cs`) | `SetupWizardWindow.xaml` | `StpWiz` |
| `Lang.xaml` (+ `.cs`) | Language picker window | `Lang` |
| `LangVM.cs` | Language window ViewModel | `LangVM` |
| `AppState.cs` | Application session state | `AppState` |

### Module Views — `Views/Modules/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `ModWsVw.xaml` (+ `.cs`) | `ModuleWorkspaceView.xaml` | `ModWsVw` |
| `DashVw.xaml` (+ `.cs`) | `DashboardView.xaml` | `DashVw` |

### Services — `Services/`

| ملف مختصر | اسم طويل الأصلي | Class / Interface |
|-----------|-----------------|-------------------|
| `AppHost.cs` | `AppServiceHost.cs` | `AppHost` |
| `AuthServ.cs` | `AuthService.cs` | `AuthServ` |
| `IAuthSvc.cs` | `IAuthService.cs` | `IAuthSvc` |
| `NavServ.cs` | `NavigationService.cs` | `NavServ` |
| `LogServ.cs` | `LoggingService.cs` | `LogServ` |
| `PermServ.cs` | `PermissionService.cs` | `PermServ` |
| `ThmServ.cs` | `ThemeService.cs` | `ThmServ` |
| `BkpServ.cs` | `BackupService.cs` | `BkpServ` |
| `IBkpSvc.cs` | `IBackupService.cs` | `IBkpSvc` |
| `DataServ.cs` | `DataService.cs` | `DataServ` |
| `CoRegSvc.cs` | `CompanyRegistryService.cs` | `CoRegSvc` (implements `ICoRegSvc`) |
| `LangDirSv.cs` | `LanguageDirectionService.cs` | `LangDirSv` |
| `ShlChrHlpr.cs` | `ShellChromeHelper.cs` | `ShlChrHlpr` |
| `UsrSession.cs` | `UserSession.cs` | `UsrSession` |
| `UsrAccLvl.cs` | `UserAccessLevel.cs` | enum `UsrAccLvl` |
| `UsrPrefSvc.cs` | User preferences service | `UsrPrefSvc` |
| `ILocSvc.cs` | `ILocalizationService.cs` + `LocalizationService` | `ILocSvc` / `LocSvc` |
| `IServices.cs` | Core service interfaces | `IDataServ`, `INavSvc`, `IPermSvc`, … |

### Online Services — `Services/Online/`

| ملف مختصر | اسم طويل الأصلي | Class / Interface |
|-----------|-----------------|-------------------|
| `OnlCoord.cs` | `OnlineServicesCoordinator.cs` | `OnlCoord` |
| `IOnlCoord.cs` | `IOnlineServicesCoordinator.cs` | `IOnlCoord` |
| `ConnServ.cs` | `ConnectivityService.cs` | `ConnServ` |
| `IConnSvc.cs` | `IConnectivityService.cs` | `IConnSvc` |
| `SyncServ.cs` | `SyncService.cs` | `SyncServ` |
| `ISyncSvc.cs` | `ISyncService.cs` | `ISyncSvc` |
| `LicenSvc.cs` | `LicenseService.cs` | `LicenSvc` |
| `ILicenSvc.cs` | `ILicenseService.cs` | `ILicenSvc` |
| `DevInfoSv.cs` | `DeviceInfoService.cs` | `DevInfoSv` |
| `IDevInfoSv.cs` | `IDeviceInfoService.cs` | `IDevInfoSv` |

### Configuration — `Configuration/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `AppCfgSvc.cs` | `AppConfigService.cs` | `AppCfgSvc` |
| `AppSetng.cs` | `AppSettings.cs` | `AppSetng` |
| `AppPrefs.cs` | `AppPreferences.cs` + `AppPreferencesService` | `AppPrefs` / `AppPrefsSvc` |

### Common — `Common/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `AppFormat.cs` | `AppFormats.cs` | `AppFormat` |
| `JsonDefs.cs` | `JsonDefaults.cs` | `JsonDefs` |
| `StatBarEn.cs` | Status bar English texts (`StatBar`) | `StatBarEn` |

### Localization — `Localization/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `Loc.cs` | Localization helper | `Loc` |
| `LocProps.cs` | `LocalizationProperties.cs` | `LocProps` |
| `UiLoczr.cs` | `UiLocalizer.cs` | `UiLoczr` |

### Navigation — `Navigation/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `RibModMap.cs` | `RibbonModuleMapper.cs` | `RibModMap` |

### Converters — `Converters/`

| ملف مختصر | Class داخل الملف | اسم طويل الأصلي |
|-----------|------------------|-----------------|
| `BoolVis.cs` | `BoolVis` | `BoolToVisibilityConverter` |
| `BoolVis.cs` | `InvBVis` | `InverseBoolToVisibilityConverter` |
| `BoolVis.cs` | `InvBool` | `InverseBooleanConverter` |
| `BoolVis.cs` | `NullVis` | `NullToVisibilityConverter` |
| `LangFlwCv.cs` | `LangFlwCv` | `LanguageToFlowDirectionConverter` |

### Themes — `Themes/`

| ملف مختصر | اسم طويل الأصلي | نوع |
|-----------|-----------------|-----|
| `DkTheme.xaml` | `DarkTheme.xaml` | ResourceDictionary |
| `LtTheme.xaml` | `LightTheme.xaml` | ResourceDictionary |
| `ShMenu.xaml` | `ShellMenuStyles.xaml` | ResourceDictionary |
| `ShRibn.xaml` | `ShellRibbonStyles.xaml` | ResourceDictionary |

---

## Core / Inventory — `cod/cor/`

| ملف مختصر | اسم طويل / المعنى | Class |
|-----------|-------------------|-------|
| `navrep.cs` | Navigation repository | `NavigationRepository` |
| `invrep.cs` | Inventory repository | — |
| `invsvc.cs` | Inventory service | — |
| `invuow.cs` | Inventory unit of work | — |
| `invmod.cs` | Inventory models | — |
| `Models.cs` | Shared models | — |
| `Security.cs` | Security helpers | — |

---

## Configuration خارج المشروع — `cfg/`

| ملف مختصر | اسم طويل الأصلي | Class |
|-----------|-----------------|-------|
| `UsrPref.cs` | User preferences | `UsrPref` |
| `appset.json` | Application settings (deploy) | — |

---

## Domain — `src/ShouTech.Domain/`

| ملف / مسار | ملاحظة |
|------------|--------|
| `Pref.cs` | User preference model (encrypted local storage) |
| `Entities/Navigation/NavigationModels.cs` | Navigation DTOs (لم يُختصر بعد) |
| `Interfaces/INavigationRepository.cs` | Navigation repo contract |

---

## أدوات الصيانة — `tools/`

| سكربت | الغرض |
|-------|--------|
| `rename_short.ps1` | الاختصار الأولي للأسماء الطويلة |
| `rename_distinct.ps1` | تمييز الأسماء المتشابهة (+1–2 حرف) |
| `generate_nav_seed.ps1` | توليد `dba/sds/sds_nav.sql` من XAML + Lang JSON |

---

## علاقات ملفات مترابطة (XAML + Code-behind + VM)

```
LogWin.xaml  ←→  LogWin.xaml.cs  ←→  LogWinVM.cs
MWin.xaml    ←→  MWin.xaml.cs    ←→  MainShVM.cs
ModWsVw.xaml ←→  ModWsVw.xaml.cs ←→  ModWsVM.cs
SplWin.xaml  ←→  SplWin.xaml.cs
ComWin.xaml  ←→  ComWin.xaml.cs
```

---

## ملاحظات للمطورين

1. **لا تغيّر `Application.MainWindow`** — خاصية WPF؛ اسم النافذة المختصر هو Class `MWin` فقط.
2. **شريط الحالة** يستخدم `StatBarEn` (إنجليزي ثابت) — لا يمر عبر `LocSvc`.
3. **خدمات Online** (مزامنة، ترخيص، اتصال) تعمل في الخلفية ولا تُعرض تفاصيلها في UI.
4. عند إضافة ملف جديد: اتبع نفس النمط (`LogWin`, `NavServ`, `ModWsVM`) وحدّث هذا الملف.

---

*آخر تحديث: 2026-08-13 · ShouTech ERP v10.6*
