clowde
# 📋 SHOUTECH ERP V9 - ملخص نقاطي احترافي

---

# 🎯 1. الرؤية والهدف

- بناء نظام ERP يتفوق على **الأمين 9** و **فينكس 9**
- منافسة أنظمة عالمية مثل **SAP** و **Odoo**
- مطور منفرد يمتلك **C#** + **C++** + **Python**
- البرنامج يعمل **Offline** مع تفعيل **Online**
- اسم النظام: **SHOUTECH ERP V9**

---

# 👨‍💻 2. اللغات البرمجية وأدوارها

- **C#** → الواجهات + المحركات + Business Logic
- **C++** → الحماية + الدونغل + التشفير
- **Python** → الذكاء الاصطناعي (مرحلة لاحقة)
- **SQL Server 2022** → قاعدة البيانات
- **Dapper** → ORM (بدلاً من EF Core للأداء)
- **FastReport** → التقارير والطباعة
- **ONNX Runtime** → نموذج AI للعمل Offline

---

# 🏗️ 3. المعمارية العامة

- اعتماد **Clean Architecture** (Domain → Application → Infrastructure)
- فصل كامل بين الطبقات (Presentation / Business / Data)
- نظام **Modular Plugin** لإضافة ملحقات مستقبلاً
- **Single Instance** فقط (منع فتح نسختين)
- **SYNC** كـ Windows Service وليس EXE عادي
- **Python** يتواصل مع C# عبر **FastAPI (localhost:5050)**
- كل منطق الحماية في **C++ فقط** لا في C#

---

# 📂 4. هيكل الملفات الرئيسي

- **BIN/** → LNC.exe + MAIN.exe + AUTH.exe
- **LIB/** → KERN.dll + DATA.dll + ROT.dll + PRNT.dll
- **SEC/** → PROT.cpp + CIPH.cpp + SecEng.dll
- **DBA/** → MST.sys + MST.bak + tmpl.sql + sch/
- **EXT/** → HR.dll + MFG.dll + manifest.json
- **INT/** → BRAI.py + FORE.onnx
- **CFG/** → appsettings.json + user.config
- **RPT/** → قوالب FastReport
- **TST/** → UnitTests + IntegrationTests
- **BKP/** → LOCL/ + CLD/
- **LOG/** → AUDT.log + ERRS.log
- **SVC/** → SYNC.Service.cs
- **DOC/** → MAP.md + Architecture.md

---

# 🔐 5. نظام الحماية والأمان

- **الدونغل إلزامي** - بدونه وضع Demo/Viewer فقط
- **PROT.dll (C++)** → قراءة الدونغل + HWID + Anti-Debug + Anti-VM
- **CIPH.dll (C++)** → AES-256 + RSA Signature + File Encryption
- **DPAPI** لحفظ المفاتيح الحساسة في Windows
- **RSA Signed License** لمنع التزوير
- **EXE Integrity Check** عند كل تشغيل
- **C# Obfuscation** لمنع الهندسة العكسية
- **Fallback طوارئ** → Viewer Mode + رمز مؤقت 24 ساعة

---

# 🔑 6. نظام التفعيل والترخيص

- تفعيل عبر **Email + Password + Phone**
- ربط الترخيص بـ **Dongle Serial + Hardware ID**
- تحقق يومي صامت عند توفر الإنترنت
- مهلة **3 أيام** إذا فشل الاتصال
- عند إلغاء الترخيص → تحول لـ Viewer Mode تدريجياً
- دعم **تعدد الأجهزة** تحت نفس الحساب بحد أقصى محدد

---

# 📦 7. نموذج البيع والإصدارات

- **شراء مرة واحدة** لكل إصدار رئيسي (Major)
- التحديثات الفرعية **(Minor + Patch) مجانية**
- ترقية Major بـ **سعر جزئي** (Upgrade Fee)
- نظام **Major.Minor.Patch** (مثال: V9.0.0)
- **Starter** + **Professional** + **Enterprise** Editions
- **Viewer Mode** للاستعراض فقط
- **Demo** 7 أيام بدون دونغل

---

# 🧩 8. نظام الملحقات (Modules)

- **HR Module** → موظفين + رواتب
- **Manufacturing Module** → إنتاج + BOM
- **AI Analytics** → تحليل + تنبؤ
- **Advanced Reports** → تقارير متقدمة
- تحميل ديناميكي عبر **AssemblyLoadContext**
- كل Module يُفعّل عبر **License JSON**
- إضافة Module جديد بمجرد وضع DLL في مجلد EXT/

---

# 🏢 9. نظام الشركات والسنوات

- دعم **Multi-Company** + **Multi-Year**
- **قاعدة بيانات مستقلة** لكل سنة مالية
- **MST.sys** يفهرس الشركات والسنوات والمسارات
- نافذة اختيار الشركة **قبل تسجيل الدخول**
- عرض شجرة (Groups → Companies → Years)
- إغلاق السنة → **IsClosed = true** (استعراض فقط)
- تدوير البيانات → نقل الأرصدة للسنة الجديدة

---

# 🗄️ 10. معمارية قاعدة البيانات

- **MST.sys** → قاعدة مركزية (Companies + Users + Licenses)
- **sch/** → جداول المعاملات فقط (بدون ازدواجية)
- **tmpl.sql** → يبني قاعدة السنة من ملفات sch/
- جميع المفاتيح **GUID** (وليس Auto-Increment)
- **RowVersion** في كل جدول مهم
- **Soft Delete** بدلاً من الحذف الفعلي
- **Schema Version Control** للترقيات
- **Foreign Keys** + **Check Constraints** صارمة
- **Indexes** محسنة على (CompanyId + Date)

---

# 📊 11. جداول قاعدة البيانات الرئيسية

### MST.sys:
- Groups, Companies, FiscalYears
- Users, Roles, Permissions, RolePermissions
- RegisteredDevices, LicenseInfo
- BackupLog, SystemSettings, SchemaVersion

### sch/fin.sql:
- Invoices, InvoiceItems
- JournalEntries, JournalLines
- Payments, BankAccounts

### sch/inv.sql:
- Items, ItemCategories
- Warehouses, StockMovements

### sch/crm.sql:
- Customers, Suppliers
- CRM_Activities, Leads

### sch/hr.sql:
- Employees, Payroll, Attendance

### sch/mfg.sql:
- ProductionOrders, BillOfMaterials

### sch/acc.sql:
- Accounts (شجرة الحسابات), CostCenters

### sch/curr.sql:
- Currencies, ExchangeRates

### sch/aud.sql:
- AuditLogs, Attachments

### sch/sys.sql:
- LocalSettings, PrintTemplates

---

# 💾 12. نظام النسخ الاحتياطي (10/3 Rule)

- **محلي:** 10 نسخ Rolling FIFO لكل شركة
- **ثانوي:** 10 نسخ في Partition مختلف
- **سحابي:** 3 نسخ فقط في السيرفر الخاص
- تشفير كامل بـ **AES-256** قبل الحفظ
- تسمية احترافية: `COMP01_FULL_2026-05-28_23-15-42.enc`
- **Metadata** داخل كل نسخة (AccountId + Checksum)
- تحقق من سلامة الملف قبل الحذف
- إشعار يومي في الواجهة الرئيسية
- حذف الأقدم تلقائياً عند تجاوز الحد
- **Backup Health Score** لمراقبة حالة النسخ

---

# ☁️ 13. سياسة الاسترجاع السحابي

- السيرفر السحابي **خاص وغير متاح للعموم**
- الاسترجاع عبر **مندوب الشركة فقط**
- يتم بـ **Support Code** مؤقت
- الشركة تستطيع الاطلاع على النسخ **للرقابة والصيانة**
- كل اطلاع مسجل في **Access Logs**
- صلاحيات محددة لكل موظف داخلي
- بند قانوني في عقد الترخيص

---

# ⚙️ 14. Tech Stack المعتمد

| المكون | التقنية | الإصدار |
|--------|---------|---------|
| Desktop UI | WPF | .NET 9 |
| Business Logic | C# | .NET 9 |
| Security | C++ | 20 |
| Database | SQL Server Express | 2022 |
| ORM | Dapper | Latest |
| Reporting | FastReport | .NET 9 |
| AI Engine | Python FastAPI | 3.12 |
| AI Model | ONNX Runtime | Offline |
| Logging | Serilog | Latest |

---

# 🌍 15. دعم تعدد اللغات

- **العربية** → افتراضي + RTL كامل
- **الإنجليزية** → LTR
- **الفرنسية** → LTR
- **التركية** → LTR
- ملفات **.resx** لكل لغة
- **LocalizationManager** Singleton
- تبديل فوري **بدون إعادة تشغيل**
- الواجهة تنقلب بالكامل مع تغيير اللغة
- حفظ تفضيل المستخدم في MST.sys
- خط **Cairo** كخط افتراضي يدعم كل اللغات

---

# 🎨 16. نظام الهوية البصرية المركزية

- ملف **appsettings.json** مرجع مركزي لكل شيء
- يحتوي: الألوان + الخطوط + القياسات + الأزرار
- **Design Tokens** للأحجام (Small/Medium/Large/Fill)
- **Semantic Styles** في XAML ResourceDictionary
- دعم **Dark Mode** و **Light Mode**
- تخصيص الشعار والألوان لكل عميل
- **user.config** لحفظ تفضيلات المستخدم

---

# 📐 17. نظام الحقول الدلالي

| النمط | الاستخدام | العرض |
|-------|----------|-------|
| InputSmall | أرقام صغيرة | 80px |
| InputMedium | أكواد + هواتف | 150px |
| InputLarge | أسماء + عناوين | 250px |
| InputFill | يملأ المساحة | * |
| InputDate | التاريخ | 100px |
| InputNumber | محاذاة يمين | 80px |
| InputTextArea | ملاحظات | متعدد الأسطر |

---

# 🗓️ 18. خطة التنفيذ (9 أشهر)

- **Phase 0** (أسبوعان) → Foundation + Git + Solution
- **Phase 1** (شهر 1) → Security (PROT.dll + CIPH.dll)
- **Phase 2** (شهر 2) → Database (MST.sys + sch/ + tmpl.sql)
- **Phase 3** (شهر 3-4) → Financial Engine (KERN.dll)
- **Phase 4** (شهر 4) → Data Layer (DATA.dll + Dapper)
- **Phase 5** (شهر 5) → Core UI (LNC.exe + MAIN.exe)
- **Phase 6** (شهر 6) → Backup + SYNC Service + AUTH
- **Phase 7** (شهر 7) → Modules + Plugin System
- **Phase 8** (شهر 8) → AI Engine (Python FastAPI)
- **Phase 9** (شهر 9) → Performance + Market Ready

---

# ⚠️ 19. التحذيرات والقرارات الحرجة

- ❌ لا تبدأ UI قبل إنهاء Security + Database + Engine
- ❌ لا تضع منطق حماية في C# أبداً
- ❌ لا تستخدم EF Core (استخدم Dapper)
- ❌ لا تحذف MST.sys (هو العقل المدبر)
- ❌ لا تخزن المفاتيح في ملفات نصية عادية
- ✅ KERN.dll يجب اختباره مع محاسب خبير
- ✅ MST.sys يجب نسخة احتياطية يومية تلقائية
- ✅ SYNC يجب أن يعمل كـ Windows Service
- ✅ كل عملية تسجل في AuditLogs
- ✅ اختبر مع 500k فاتورة قبل الإطلاق

---

# 🏆 20. نقاط التفوق على المنافسين

- ✅ أمان C++ (Dongle + RSA) مقابل مفتاح بسيط
- ✅ Modular Plugin System مقابل نظام مغلق
- ✅ نسخ احتياطي تلقائي متعدد المستويات
- ✅ دعم 4 لغات مع RTL/LTR ديناميكي
- ✅ Cloud Backup خاص ومشفر
- ✅ AI مدمج للتحليل والتنبؤ
- ✅ أداء Dapper مع SQL Server محسّن
- ✅ واجهة حديثة WPF مع Dark Mode
- ✅ تحكم مركزي بالأجهزة والتراخيص
- ✅ إغلاق سنة + تدوير بيانات احترافي

---

# 🔥 الخلاصة في جملة واحدة

> **SHOUTECH ERP V9** = نظام مؤسسي متكامل يجمع بين أمان عسكري (C++) وأداء عالي (Dapper) ومرونة كاملة (Modular) وذكاء اصطناعي (Python ONNX) في حزمة واحدة تتفوق على المنافسين المحليين وتنافس العالميين. 🚀

gemeny

إليك الملخص الهندسي والاستراتيجي لنظام **SHOUTECH ERP V9** مصاغاً في نقاط مركزة واحترافية:

### 🎯 الرؤية والتوجه العام
*   **الهدف:** بناء نظام ERP يتفوق على البرامج القديمة (مثل الأمين وفينكس) بالسرعة، الذكاء، والأمان.
*   **بيئة العمل:** نظام يعمل محلياً (Offline-First) مع مزامنة سحابية لحظية (Real-time Cloud Sync).

### 🛠️ التقنيات واللغات (Tech Stack)
*   **C# (.NET 9 / WPF):** لبناء الواجهات الرصرية، المحرك المحاسبي، وإدارة قواعد البيانات.
*   **C++ 20:** للدرع الأمني، التواصل مع الدونغل المادي، وتشفير البيانات.
*   **Python 3.12:** لمحرك الذكاء الاصطناعي، كشف التلاعب (Fraud Detection)، والتنبؤ بالمبيعات.
*   **gRPC:** لضمان تواصل داخلي فائق السرعة بين C# وبايثون.

### 🏗️ المعمارية الهندسية (Architecture)
*   **فصل البيانات (Decoupling):** عزل "قاعدة الفهرس" (`MST.sys`) عن "قواعد العمليات" (`N24.db` لسنوات الشركات).
*   **أداء فائق (Zero-Lag):** قاعدة بيانات مستقلة لكل سنة مالية/شركة لضمان سرعة الاستعلام مهما زاد حجم العمل.
*   **اللانشر الذكي (`LNC.exe`):** واجهة خفيفة تسبق البرنامج، وظيفتها فحص العتاد وعرض شجرة الشركات.
*   **نظام الملحقات (Plugins):** بنية معمارية تسمح بتركيب موديولات إضافية (HR، تصنيع) دون تعديل النواة.

### 🛡️ منظومة الأمان والتراخيص
*   **مصادقة ثلاثية الأبعاد:** يعمل البرنامج فقط عند تطابق (الدونغل المادي + بصمة الجهاز HWID + الترخيص السحابي).
*   **تشفير سيادي:** استخدام (Windows DPAPI) لحماية مفاتيح التشفير، مما يمنع سرقتها حتى من داخل الجهاز.
*   **تراخيص ديناميكية:** التحكم بصلاحيات العميل (تفعيل الملحقات) عبر نظام البتات (Bitmask) برمجياً.

### 💾 سياسة النسخ والتعافي (Resilience & Backups)
*   **سياسة (10/3) الدائرية:** الاحتفاظ بـ 10 نسخ احتياطية محلياً، و 3 نسخ سحابياً، مع حذف الأقدم آلياً (FIFO).
*   **الميرور اللحظي:** خدمة خلفية (`SYNC.srv`) ترفع كل حركة مالية للسيرفر فور توفر الإنترنت.
*   **التعافي الذاتي:** وجود ملف بديل للفهرس (`Shadow Master`) يتم استرجاعه آلياً في حال تلف الملف الرئيسي.

### 📐 هندسة قواعد البيانات (Database Design)
*   **منع الازدواجية:** حصر جداول المستخدمين والشركات والتراخيص في ملف الفهرس فقط، ومنع تكرارها في ملفات السنوات.
*   **التوافق السحابي:** الاعتماد على الـ (GUID) كمفاتيح أساسية لضمان عدم تضارب البيانات عند دمج الفروع.
*   **الرقابة والذكاء:** استخدام حقول (JSON) في جداول التدقيق (Audit) لتخزين التغييرات (Old/New) لتغذية الذكاء الاصطناعي.

### 🎨 واجهات المستخدم والتخصيص (UI/UX)
*   **تصميم متجاوب (Responsive):** التخلي عن المقاسات الثابتة لصالح نظام "الشبكات المرنة" ليتناسب البرنامج مع كل الشاشات.
*   **هوية بصرية مركزية:** ملف ثيمات موحد (`theme_master.xaml`) يتيح تفعيل الوضع الليلي (Dark Mode) وتخصيص ألوان الشركات (White-labeling).
*   **دعم العالمية:** تغيير لحظي للغة والمحاذاة (RTL/LTR) لدعم (العربية، الإنجليزية، التركية، الفرنسية) من النواة.