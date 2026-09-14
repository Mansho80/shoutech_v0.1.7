## Local database connection

The development build reads the SQL Server connection from the
`SHOUTECH_DB_CONNECTION` environment variable. Keep credentials out of
`cfg/appset.json` and out of source control.

Example for Windows PowerShell:

```powershell
$env:SHOUTECH_DB_CONNECTION = "Server=localhost;Database=SHOUTECH_MST;Integrated Security=True;TrustServerCertificate=True;"
dotnet run --project .\cod\app\src\MainApp.csproj
```

Apply database migrations with a controlled SQL Server deployment process in
this order: `dba\mst\mst.sql`, `dba\mig\001_init.sql`, `dba\mig\002_curr.sql`,
`dba\mig\003_accounting_journal.sql`.
ShouTech ERP V9 - Development Guide (Scaffold)
=============================================

هذا دليل تطوير سريع لمشروع ShouTech عندما تكون النسخ الحقيقية مفقودة جزئياً.

خطوات سريعة بعد الاستنساخ:

1. تثبيت المتطلبات:
   - .NET SDK (7.0+) أو حسب النسخة المستهدفة.
   - Visual Studio (لـ C++ وMSVC) إن كنت ستبني محرك الأمان.
   - SQL Server 2019/2022 أو LocalDB.

2. تشغيل السكربت لبناء المشاريع التجريبية:

```powershell
.\build.ps1 -Configuration Debug
```

3. إذا تملك نسخة احتياطية لسورس المشروع الحقيقي، استرجعها وضعها مكان الملفات الفارغة (`*.csproj`, `ShouTech.sln`, ملفات EXE/DLL الحقيقية).

4. لبناء محرك الأمان `SecEng.dll` افتح `sec\src` في Visual Studio وأنشئ مشروع vcxproj مطابق لإعدادات MSVC (C++20).

ملاحظات:
- الملفات الحالية في `cod\app\src` هي سكافولد للتطوير فقط.
- تابع ملف `restore_plan.txt` لحالة الملفات المفقودة وخطوات الاسترجاع.
