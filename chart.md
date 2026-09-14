Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\Users\mansh\OneDrive\Desktop\shoutech_erp_v0.1.6> tree /f /a
Folder PATH listing
Volume serial number is 000000CF 5C5F:82FB
C:.
|   .gitattributes
|   .gitignore
|   build.ps1
|   build_errors.txt
|   build_errors_utf8.txt
|   chart.md
|   Directory.Build.props
|   docker-compose.yml
|   LICENSE
|   MANIFEST.md
|   nuget.config
|   README.dev.md
|   readMe.md
|   remaining_errors.txt
|   restore_plan.txt
|   ShouTech.sln
|   shoutech_erp_v0.1.601.zip
|   sum.md
|   UIchart.md
|
+---archive
+---bkp
|   +---cld
|   \---locl
+---bld
|       bld.bat
|       pkg.ps1
|       sgn.ps1
|
+---cfg
|       appset.json
|       license.dat
|       UsrPref.cs
|
+---cod
|   +---app
|   |   |   auth.exe
|   |   |   data.dll
|   |   |   lnc.exe
|   |   |   main.exe
|   |   |   prnt.dll
|   |   |   rot.dll
|   |   |   SecEng.dll
|   |   |
|   |   \---src
|   |       |   App.xaml
|   |       |   App.xaml.cs
|   |       |   expanded.xml
|   |       |   MainApp.csproj
|   |       |   scr.py
|   |       |   Services.zip
|   |       |
|   |       +---Common
|   |       |       AppFormat.cs
|   |       |       AppLang.cs
|   |       |       ArabCountries.cs
|   |       |       ArabCurr.cs
|   |       |       JsonDefs.cs
|   |       |       PwdHash.cs
|   |       |       ShellWinDock.cs
|   |       |       StatBarEn.cs
|   |       |       WinMgr.cs
|   |       |
|   |       +---Configuration
|   |       |       AppCfgSvc.cs
|   |       |       AppConfigService.cs
|   |       |       AppPreferences.cs
|   |       |       AppPrefs.cs
|   |       |       AppSetng.cs
|   |       |       AppSettings.cs
|   |       |       UsrPref.cs
|   |       |
|   |       +---Converters
|   |       |       BoolToVisibilityConverter.cs
|   |       |       BoolVis.cs
|   |       |       InverseBoolToVisibilityConverter.cs
|   |       |       LangFlwCv.cs
|   |       |       LanguageToFlowDirectionConverter.cs
|   |       |       NullToVisibilityConverter.cs
|   |       |
|   |       +---Interaction
|   |       |       EntityContextAction.cs
|   |       |
|   |       +---Localization
|   |       |       Loc.cs
|   |       |       LocProps.cs
|   |       |       UiLoczr.cs
|   |       |
|   |       +---Navigation
|   |       |       RibbonModuleMapper.cs
|   |       |       RibModMap.cs
|   |       |
|   |       +---Resources
|   |       |   +---Icons
|   |       |   \---Lang
|   |       |           Ar.json
|   |       |           En.json
|   |       |           Fr.json
|   |       |           Tr.json
|   |       |
|   |       +---Services
|   |       |   |   AccServ.cs
|   |       |   |   AppHost.cs
|   |       |   |   AuditService.cs
|   |       |   |   AuthServ.cs
|   |       |   |   BkpServ.cs
|   |       |   |   CoCreateSvc.cs
|   |       |   |   CoLocalStore.cs
|   |       |   |   CoModels.cs
|   |       |   |   CoRegSvc.cs
|   |       |   |   DataServ.cs
|   |       |   |   IAccServ.cs
|   |       |   |   IAuthSvc.cs
|   |       |   |   IBkpSvc.cs
|   |       |   |   IInvServ.cs
|   |       |   |   ILicServ.cs
|   |       |   |   ILocalizationService.cs
|   |       |   |   ILocSvc.cs
|   |       |   |   InvServ.cs
|   |       |   |   IPermServ.cs
|   |       |   |   IServices.cs
|   |       |   |   LangDirSv.cs
|   |       |   |   LicServ.cs
|   |       |   |   LoggingService.cs
|   |       |   |   LogServ.cs
|   |       |   |   ModMenuServ.cs
|   |       |   |   NavServ.cs
|   |       |   |   PermServ.cs
|   |       |   |   PwdHash.cs
|   |       |   |   SessionManager.cs
|   |       |   |   ShlChrHlpr.cs
|   |       |   |   ThemeService.cs
|   |       |   |   ThmServ.cs
|   |       |   |   UsrAccLvl.cs
|   |       |   |   UsrPrefSvc.cs
|   |       |   |   UsrSession.cs
|   |       |   |
|   |       |   +---Online
|   |       |   |       ConnServ.cs
|   |       |   |       DevInfoSv.cs
|   |       |   |       IConnSvc.cs
|   |       |   |       IDevInfoSv.cs
|   |       |   |       ILicenSvc.cs
|   |       |   |       IOnlCoord.cs
|   |       |   |       ISyncSvc.cs
|   |       |   |       LicenSvc.cs
|   |       |   |       OnlCoord.cs
|   |       |   |       SyncServ.cs
|   |       |   |
|   |       |   \---security
|   |       |           PermCat.cs
|   |       |
|   |       +---Themes
|   |       |       DarkTheme.xaml
|   |       |       DkTheme.xaml
|   |       |       LightTheme.xaml
|   |       |       LtTheme.xaml
|   |       |       ShMenu.xaml
|   |       |       ShRibn.xaml
|   |       |
|   |       +---ViewModels
|   |       |       BaseVM.cs
|   |       |       DockedWinItem.cs
|   |       |       LogWinVM.cs
|   |       |       MainShVM.cs
|   |       |       MainWnVM.cs
|   |       |       ModWsVM.cs
|   |       |       RibbonTabViewModel.cs
|   |       |
|   |       \---Views
|   |           |   AppState.cs
|   |           |   ComWin.xaml
|   |           |   ComWin.xaml.cs
|   |           |   Lang.xaml
|   |           |   Lang.xaml.cs
|   |           |   LangVM.cs
|   |           |   LogWin.xaml
|   |           |   LogWin.xaml.cs
|   |           |   MWin.xaml
|   |           |   MWin.xaml.cs
|   |           |   SplWin.xaml
|   |           |   SplWin.xaml.cs
|   |           |   StpWiz.xaml
|   |           |   StpWiz.xaml.cs
|   |           |
|   |           \---Modules
|   |               |   DashboardView.xaml
|   |               |   DashboardView.xaml.cs
|   |               |   DashVw.xaml
|   |               |   DashVw.xaml.cs
|   |               |   ModuleWorkspaceView.xaml
|   |               |   ModuleWorkspaceView.xaml.cs
|   |               |   ModWsVw.xaml
|   |               |   ModWsVw.xaml.cs
|   |               |
|   |               +---Base
|   |               +---File
|   |               \---Inventory
|   +---cor
|   |       data.dll
|   |       inv.csproj
|   |       invmod.cs
|   |       invrep.cs
|   |       invsvc.cs
|   |       invuow.cs
|   |       kern.dll
|   |       Models.cs
|   |       navrep.cs
|   |       prnt.dll
|   |       rot.dll
|   |       Security.cs
|   |
|   +---shd
|   |   +---com
|   |   \---sec
|   \---tst
|       +---int
|       \---uni
+---dba
|   |   01_SEC.sql
|   |   02_GL_COA.sql
|   |   03_CASH.sql
|   |   04_SALES.sql
|   |   05_PURCH.sql
|   |   06_INV.sql
|   |   crm.sys
|   |   DBChart.md
|   |   fin.sys
|   |   hr.sys
|   |   install.sys
|   |   inv.sys
|   |   mfg.sys
|   |   sec.sys
|   |
|   +---ai
|   |       anom.sql
|   |       model.sql
|   |       pred.sql
|   |
|   +---aud
|   |       appr.sql
|   |       log.sql
|   |       retn.sql
|   |
|   +---crm
|   |       cont.sql
|   |       crm.sql
|   |       cust.sql
|   |       lead.sql
|   |       price.sql
|   |
|   +---fin
|   |       coa.sql
|   |       fin.sql
|   |       fin_asst.sql
|   |       gl.sql
|   |       inv.sql
|   |       pay.sql
|   |       rpt.sql
|   |
|   +---hr
|   |       att.sql
|   |       emp.sql
|   |       hr.sql
|   |       leave.sql
|   |       payr.sql
|   |
|   +---inv
|   |       inv.sql
|   |       move.sql
|   |       prod.sql
|   |       stock.sql
|   |       val.sql
|   |       wh.sql
|   |
|   +---mfg
|   |       bom.sql
|   |       mfg.sql
|   |       qual.sql
|   |       route.sql
|   |       wo.sql
|   |
|   +---mig
|   |       001_init.sql
|   |       002_curr.sql
|   |       002_seed_developer_account.sql
|   |       003_accounting_journal.sql
|   |       003_nav_ribbon.sql
|   |
|   +---mst
|   |       aud.sql
|   |       lic.sql
|   |       mst.sql
|   |       proc.sql
|   |       usr.sql
|   |
|   +---pos
|   |       pos.sql
|   |       pos_trns.sql
|   |       shift.sql
|   |
|   +---post
|   |       post.sql
|   |
|   +---scr
|   +---sds
|   |       sds_crm.sql
|   |       sds_fin.sql
|   |       sds_hr.sql
|   |       sds_inv.sql
|   |       sds_mfg.sql
|   |       sds_nav.sql
|   |       sds_pos.sql
|   |       sds_sys.sql
|   |       su_sds_coa.sql
|   |       sy_sds_coa.sql
|   |
|   +---sys
|   |       nav.sql
|   |       NAV_README.md
|   |       noti.sql
|   |       seq.sql
|   |       sett.sql
|   |       sys.sql
|   |       tax.sql
|   |
|   \---tmpl
|           TMPL.sql
|
+---doc
|       api.md
|       arc.md
|       dep.md
|       sec.md
|       UIchart.md
|       usr.md
|
+---docs
|       FILE_ABBR.md
|       SHOUTECH_ERP.md
|       SHOUTECH_ERP_EN.md
|
+---ext
|       hr.dll
|       man.json
|       mfg.json
|
+---int
|       brai.py
|       fore.onnx
|       req.txt
|
+---lib
|       data.dll
|       kern.dll
|       prnt.dll
|       rot.dll
|
+---log
|       audt.log
|       errs.log
|
+---rpt
|       balance_sheet.frx
|       invoice_sales.frx
|       trial_balance.frx
|
+---sec
|   |   CMakeLists.txt
|   |
|   +---inc
|   |       sec.h
|   |
|   +---src
|   |       ciph.cpp
|   |       prot.cpp
|   |
|   \---vcx
|           sec.vcxproj
|
+---src
|   +---ShouTech.Application
|   |   |   Class1.cs
|   |   |   Loc.cs
|   |   |   ShouTech.Application.csproj
|   |   |
|   |   +---Interfaces
|   |   \---Services
|   |           ComSvc.cs
|   |           FYearSvc.cs
|   |           JournalService.cs
|   |           LicSvc.cs
|   |           ModMenuSvc.cs
|   |           UsrSvc.cs
|   |
|   +---ShouTech.Domain
|   |   |   Class1.cs
|   |   |   Pref.cs
|   |   |   ShouTech.Domain.csproj
|   |   |
|   |   +---DTOs
|   |   +---Entities
|   |   |   |   Comp.cs
|   |   |   |   Company.cs
|   |   |   |   Device.cs
|   |   |   |   EntBase.cs
|   |   |   |   FYear.cs
|   |   |   |   JournalEntry.cs
|   |   |   |   LicInfo.cs
|   |   |   |   Perm.cs
|   |   |   |   Rol.cs
|   |   |   |   RolPerm.cs
|   |   |   |   User.cs
|   |   |   |   Usr.cs
|   |   |   |
|   |   |   \---Navigation
|   |   |           NavigationModels.cs
|   |   |
|   |   +---Enums
|   |   |       AppMode.cs
|   |   |       LicEd.cs
|   |   |       LicenseType.cs
|   |   |       LicStat.cs
|   |   |       ModKey.cs
|   |   |
|   |   \---Interfaces
|   |           ICompanyRepository.cs
|   |           IComRepo.cs
|   |           IDatabaseHealth.cs
|   |           IDatabaseProvider.cs
|   |           IFYearRepo.cs
|   |           IJournalRepository.cs
|   |           ILicenseProvider.cs
|   |           ILicProv.cs
|   |           INavigationRepository.cs
|   |           IUserRepository.cs
|   |           IUsrRepo.cs
|   |           New Text Document.txt
|   |
|   +---ShouTech.Infrastructure
|   |   |   Class1.cs
|   |   |   ShouTech.Infrastructure.csproj
|   |   |   SqlDatabaseHealth.cs
|   |   |
|   |   +---Backup
|   |   +---Data
|   |   |   \---Providers
|   |   +---Licensing
|   |   \---Security
|   +---ShouTech.LicenseServer
|   \---ShouTech.Tests
|       \---Unit
+---svc
|       svc.csproj
|       syn.cs
|       syn.cs.bak
|
+---sys
|   \---keys
+---tests
|   \---Kern.Tests
|           Kern.Tests.csproj
|           UnitTest1.cs
|
+---tls
|   +---frp
|   |       kern_tests.cs
|   |
|   +---red
|   \---sql
\---tools
    |   apply_migrations.ps1
    |   generate_nav_seed.ps1
    |   rename_distinct.ps1
    |   rename_short.ps1
    |   rename_short2.ps1
    |
    \---SqlMigrator
            Program.cs
            SqlMigrator.csproj
