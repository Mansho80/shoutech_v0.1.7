using System;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using ShouTech.App.Common;
using ShouTech.App.Configuration;
using ShouTech.App.Services;

namespace ShouTech.App.Views
{
    public enum StpWizMode
    {
        FirstRun,
        NewCompany
    }

    public partial class StpWiz : Window
    {
        #region Constants & Fields

        private const int MinStep = 1;
        private const int MaxStep = 6;

        private readonly StpWizMode _mode;
        private readonly DispatcherTimer _autoProgressTimer;

        private int _currentStep = MinStep;
        private bool _isSaving;
        private bool _isUserInteracted;
        private bool _isCheckingPasswordAvailability;
        private bool _langUserTouched;
        private bool _syncingLanguageCombo;

        #endregion

        #region Public Properties

        public bool IsSaving => _isSaving;
        public bool CompletedSuccessfully { get; private set; }
        public string? CreatedCompanyCode { get; private set; }

        #endregion

        #region Constructors

        public StpWiz(StpWizMode mode, Window? owner = null)
        {
            _mode = mode;
            InitializeComponent();
            try { ShlChrHlpr.Apply(this); } catch { }

            ConfigureOwnership(owner);

            NumberSubstitution.SetSubstitution(this, NumberSubstitutionMethod.European);

            InitializeWizardUi();
            LoadDefaults();
            SyncLanguageComboWithApp();
            ApplyModeTexts();
            ApplyWizardLocalization();

            _autoProgressTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3.0) };
            _autoProgressTimer.Tick += AutoProgressTimer_Tick;

            RegisterEventHandlers();
            UpdateStepUi();
            Loaded += async (_, __) =>
            {
                ApplyWizardLocalization();
                if (_mode == StpWizMode.NewCompany)
                    await PopulateManagedStoragePathsAsync();
            };

            if (_mode == StpWizMode.FirstRun)
            {
                _autoProgressTimer.Start();
            }

            if (_mode == StpWizMode.NewCompany)
            {
                Title = "إنشاء شركة جديدة — ShouTech ERP";
            }
        }

        #endregion

        #region Private Configuration Methods

        private void ConfigureOwnership(Window? explicitOwner)
        {
            if (explicitOwner != null && explicitOwner != this && explicitOwner.IsVisible)
            {
                Owner = explicitOwner;
                WindowStartupLocation = WindowStartupLocation.CenterOwner;
            }
            else
            {
                var fallbackOwner = System.Windows.Application.Current?.MainWindow ?? GetActiveWindow();

                if (fallbackOwner != null && fallbackOwner != this && fallbackOwner.IsVisible)
                {
                    Owner = fallbackOwner;
                    WindowStartupLocation = WindowStartupLocation.CenterOwner;
                }
                else
                {
                    WindowStartupLocation = WindowStartupLocation.CenterScreen;
                }
            }

            ShowInTaskbar = true;
        }

        private static Window? GetActiveWindow()
        {
            var app = System.Windows.Application.Current;
            if (app == null) return null;

            return app.Windows.OfType<Window>().FirstOrDefault(w => w.IsActive && w.IsVisible);
        }

        #endregion

        #region Initialization Helpers

        private void InitializeWizardUi()
        {
            cmbCurrency.ItemsSource = ArabCurr.All;
            cmbCurrency.SelectedIndex = 0;

            var currentYear = DateTime.Today.Year;
            dpFiscalStart.SelectedDate = new DateTime(currentYear, 1, 1);
            dpFiscalEnd.SelectedDate = new DateTime(currentYear, 12, 31);
            UpdateFiscalHint();
        }

        private void RegisterEventHandlers()
        {
            btnCancel.Click += BtnCancel_Click;
            btnBack.Click += BtnBack_Click;
            btnNext.Click += BtnNext_Click;
            btnFinish.Click += BtnFinish_Click;
            if (cmbLanguageCode != null)
            {
                cmbLanguageCode.SelectionChanged += (_, _) =>
                {
                    if (_syncingLanguageCombo)
                        return;
                    _langUserTouched = true;
                    ApplyWizardLocalization();
                };
            }

            dpFiscalStart.SelectedDateChanged += (_, _) => UpdateFiscalHint();
            dpFiscalEnd.SelectedDateChanged += (_, _) => UpdateFiscalHint();
            txtAdminUser.TextChanged += TxtAdminUser_TextChanged;
            txtAdminPassword.PasswordChanged += TxtAdminPassword_PasswordChanged;

            PreviewMouseDown += (_, _) => StopAutoProgressOnUserAction();
            PreviewKeyDown += StpWiz_PreviewKeyDown;
        }

        private void LoadDefaults()
        {
            if (_mode == StpWizMode.FirstRun)
            {
                txtCompanyName.Text = "شو تيك للحلول البرمجية";
                txtCompanyNameEn.Text = "ShouTech Solutions";
                txtTaxNumber.Text = "123456789";
                txtEmail.Text = "info@shoutech.com";
                txtWebsite.Text = "https://shoutech.com";
                txtPhone.Text = "+963111234567";
                txtMobile.Text = "+963944123456";
                txtAddressLine1.Text = "دمشق - الميدان";
                txtAddressLine2.Text = "شارع كورنيش الميدان";
                txtCity.Text = "دمشق";
                txtCountry.Text = "سوريا";
                txtLicense.Text = "TR-2026-001";
                txtNotes.Text = "شركة افتراضية تم إنشاؤها عبر معالج التهيئة الأولية.";
                txtAdminUser.Text = string.Empty;
                txtAdminFullName.Text = "مدير النظام الرئيسي";
                txtAdminPassword.Password = string.Empty;
                txtAdminPasswordConfirm.Password = string.Empty;
                txtDbPath.Text = @"C:\ShouTech\Data\Database";
                txtAltDbPath.Text = @"C:\ShouTech\Data\Alternate";
                txtBkpPath.Text = @"C:\ShouTech\Backup";
                txtAltBkpPath.Text = @"C:\ShouTech\Backup\Alternate";
                return;
            }

            txtCompanyName.Text = string.Empty;
            txtCompanyNameEn.Text = string.Empty;
            txtTaxNumber.Text = string.Empty;
            txtEmail.Text = string.Empty;
            txtWebsite.Text = string.Empty;
            txtPhone.Text = string.Empty;
            txtMobile.Text = string.Empty;
            txtAddressLine1.Text = string.Empty;
            txtAddressLine2.Text = string.Empty;
            txtCity.Text = string.Empty;
            txtCountry.Text = string.Empty;
            txtLicense.Text = string.Empty;
            txtNotes.Text = string.Empty;
            txtAdminUser.Text = string.Empty;
            txtAdminFullName.Text = string.Empty;
            txtAdminPassword.Password = string.Empty;
            txtAdminPasswordConfirm.Password = string.Empty;
            txtDbPath.Text = string.Empty;
            txtAltDbPath.Text = string.Empty;
            txtBkpPath.Text = string.Empty;
            txtAltBkpPath.Text = string.Empty;

            if (_mode == StpWizMode.NewCompany)
                _ = PopulateManagedStoragePathsAsync();
        }


        private void SyncLanguageComboWithApp()
        {
            try
            {
                if (cmbLanguageCode == null)
                    return;

                var appLang = NormalizeLang(ShouTech.App.App.CurrentLanguageCode);
                ComboBoxItem? best = null;
                ComboBoxItem? fallback = null;

                foreach (var item in cmbLanguageCode.Items.OfType<ComboBoxItem>())
                {
                    var tag = NormalizeLang(item.Tag?.ToString());
                    if (string.IsNullOrEmpty(tag))
                        continue;
                    if (tag == appLang)
                    {
                        best = item;
                        break;
                    }
                    if (fallback == null && tag.StartsWith(appLang, StringComparison.Ordinal))
                        fallback = item;
                }

                _syncingLanguageCombo = true;
                try
                {
                    cmbLanguageCode.SelectedItem = best ?? fallback ?? cmbLanguageCode.Items.OfType<ComboBoxItem>().FirstOrDefault();
                }
                finally
                {
                    _syncingLanguageCombo = false;
                }

                _langUserTouched = false; // follow application language until user changes combo
            }
            catch { }
        }

        private static string NormalizeLang(string? code)
        {
            if (string.IsNullOrWhiteSpace(code))
                return "ar";
            code = code.Trim().ToLowerInvariant().Replace('_', '-');
            if (code.StartsWith("en", StringComparison.Ordinal)) return "en";
            if (code.StartsWith("fr", StringComparison.Ordinal)) return "fr";
            if (code.StartsWith("tr", StringComparison.Ordinal)) return "tr";
            if (code.StartsWith("ar", StringComparison.Ordinal)) return "ar";
            return code.Split('-')[0];
        }

        private void ApplyModeTexts()
        {
            // Texts are applied in ApplyWizardLocalization based on current language + mode.
            ApplyWizardLocalization();
        }

        private string Msg(string ar, string en, string fr, string tr) =>
            ResolveWizardLanguage() switch
            {
                "en" => en,
                "fr" => fr,
                "tr" => tr,
                _ => ar
            };

        private string ResolveWizardLanguage()
        {
            // Application language is primary so French/Turkish shell language drives the wizard.
            // Combo overrides only after the user changes it explicitly.
            if (_langUserTouched)
            {
                try
                {
                    var tag = (cmbLanguageCode?.SelectedItem as ComboBoxItem)?.Tag?.ToString();
                    if (!string.IsNullOrWhiteSpace(tag))
                        return NormalizeLang(tag);
                }
                catch { }
            }

            try
            {
                return NormalizeLang(ShouTech.App.App.CurrentLanguageCode);
            }
            catch
            {
                return "ar";
            }
        }

        private static string GetStepTitle(int step, string lang)
        {
            return (step, lang) switch
            {
                (1, "en") => "Welcome",
                (1, "fr") => "Bienvenue",
                (1, "tr") => "Hoş geldiniz",
                (1, _) => "مقدمة وترحيب",
                (2, "en") => "Company identity",
                (2, "fr") => "Identité de la société",
                (2, "tr") => "Şirket kimliği",
                (2, _) => "بيانات الشركة والهوية",
                (3, "en") => "Fiscal year",
                (3, "fr") => "Exercice fiscal",
                (3, "tr") => "Mali yıl",
                (3, _) => "السنة المالية والمدة",
                (4, "en") => "Currency & formats",
                (4, "fr") => "Devise et formats",
                (4, "tr") => "Para birimi ve biçimler",
                (4, _) => "العملة وتنسيق الحسابات",
                (5, "en") => "Administrator account",
                (5, "fr") => "Compte administrateur",
                (5, "tr") => "Yönetici hesabı",
                (5, _) => "حساب مدير النظام",
                (6, "en") => "Storage & backup",
                (6, "fr") => "Stockage et sauvegarde",
                (6, "tr") => "Depolama ve yedekleme",
                (6, _) => "مسارات التخزين والنسخ الاحتياطي",
                (_, "en") => "Setup wizard",
                (_, "fr") => "Assistant de configuration",
                (_, "tr") => "Kurulum sihirbazı",
                _ => "معالج التهيئة"
            };
        }

        /// <summary>
        /// Applies full wizard UI language (header, steps, labels, buttons) for ar/en/fr/tr.
        /// </summary>
        private void ApplyWizardLocalization()
        {
            var lang = ResolveWizardLanguage();
            var isRtl = lang == "ar";
            try
            {
                FlowDirection = isRtl ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
            }
            catch { }

            Title = lang switch
            {
                "en" => _mode == StpWizMode.NewCompany ? "New company — ShouTech ERP" : "Company setup — ShouTech ERP",
                "fr" => _mode == StpWizMode.NewCompany ? "Nouvelle société — ShouTech ERP" : "Configuration — ShouTech ERP",
                "tr" => _mode == StpWizMode.NewCompany ? "Yeni şirket — ShouTech ERP" : "Kurulum — ShouTech ERP",
                _ => _mode == StpWizMode.NewCompany ? "إنشاء شركة جديدة — ShouTech ERP" : "معالج تهيئة المؤسسة — ShouTech ERP"
            };

            txtHeaderTitle.Text = lang switch
            {
                "en" => _mode == StpWizMode.NewCompany ? "New company wizard" : "Organization setup wizard",
                "fr" => _mode == StpWizMode.NewCompany ? "Assistant nouvelle société" : "Assistant de configuration",
                "tr" => _mode == StpWizMode.NewCompany ? "Yeni şirket sihirbazı" : "Kurulum sihirbazı",
                _ => _mode == StpWizMode.NewCompany ? "معالج إنشاء شركة جديدة" : "معالج تهيئة المؤسسة"
            };

            if (_mode == StpWizMode.NewCompany)
            {
                txtPage1Title.Text = lang switch
                {
                    "en" => "Create a new company",
                    "fr" => "Créer une nouvelle société",
                    "tr" => "Yeni şirket oluştur",
                    _ => "تهيئة شركة جديدة"
                };
                txtPage1Body.Text = lang switch
                {
                    "en" => "A new company record will be created with an independent fiscal year, system administrator, and default currency to keep accounts and transactions separated.",
                    "fr" => "Un nouvel enregistrement de société sera créé avec un exercice indépendant, un administrateur et une devise par défaut afin de séparer les comptes et les transactions.",
                    "tr" => "Bağımsız mali yıl, sistem yöneticisi ve varsayılan para birimi ile yeni bir şirket kaydı oluşturulur; hesaplar ve işlemler ayrılır.",
                    _ => "سيتم إنشاء سجل كينونة جديدة مع سنة مالية مستقلة ومدير نظام وعملة افتراضية لضمان فصل الحسابات والمعاملات."
                };
                txtPage1Hint.Text = lang switch
                {
                    "en" => "Enter the required data carefully. Click Next to continue.",
                    "fr" => "Saisissez les données requises avec soin. Cliquez sur Suivant pour continuer.",
                    "tr" => "Gerekli verileri dikkatle girin. Devam için İleri'ye tıklayın.",
                    _ => "يرجى إدخال البيانات المطلوبة بدقة. اضغط «التالي» للمتابعة."
                };
            }
            else
            {
                txtPage1Title.Text = lang switch
                {
                    "en" => "About the application",
                    "fr" => "À propos de l'application",
                    "tr" => "Uygulama hakkında",
                    _ => "معلومات عن البرنامج"
                };
                txtPage1Body.Text = lang switch
                {
                    "en" => "Welcome to ShouTech ERP. This wizard helps you prepare the database, the first company profile, and the system administrator account.",
                    "fr" => "Bienvenue dans ShouTech ERP. Cet assistant vous aide à préparer la base de données, le premier profil de société et le compte administrateur.",
                    "tr" => "ShouTech ERP'ye hoş geldiniz. Bu sihirbaz veritabanını, ilk şirket profilini ve sistem yöneticisi hesabını hazırlamanıza yardımcı olur.",
                    _ => "مرحباً بك في نظام ShouTech ERP. يرافقك هذا المعالج لتهيئة قاعدة البيانات، بيانات الشركة الأولى، وتجهيز حساب مدير النظام."
                };
                txtPage1Hint.Text = lang switch
                {
                    "en" => "Click Next to start entering organization and fiscal year data.",
                    "fr" => "Cliquez sur Suivant pour commencer la saisie des données de l'organisation et de l'exercice.",
                    "tr" => "Kurum ve mali yıl verilerini girmek için İleri'ye tıklayın.",
                    _ => "اضغط «التالي» للبدء بتعبئة بيانات المؤسسة والسنوات المالية."
                };
            }

            btnCancel.Content = lang switch { "en" => "Cancel", "fr" => "Annuler", "tr" => "İptal", _ => "إلغاء" };
            btnBack.Content = lang switch { "en" => "Back", "fr" => "Précédent", "tr" => "Geri", _ => "السابق" };
            btnNext.Content = lang switch { "en" => "Next", "fr" => "Suivant", "tr" => "İleri", _ => "التالي" };
            if (!_isSaving)
                btnFinish.Content = lang switch { "en" => "Finish", "fr" => "Terminer", "tr" => "Bitir", _ => "إنهاء" };

            // Page section labels (safe if control missing)
            SetText("lblPage2Section", lang, "Company master data", "Données de la société", "Şirket temel verileri", "بيانات الشركة الأساسية");
            SetText("lblCompanyNameAr", lang, "Company name (local) *", "Nom (local) *", "Şirket adı (yerel) *", "اسم الشركة (محلي) *");
            SetText("lblCompanyNameEn", lang, "Company name (English) — optional", "Nom (anglais) — optionnel", "Şirket adı (İngilizce) — isteğe bağlı", "اسم الشركة (إنجليزي) — اختياري");
            SetText("lblTaxNumber", lang, "Tax number — optional", "Numéro fiscal — optionnel", "Vergi numarası — isteğe bağlı", "الرقم الضريبي (Tax Number) — اختياري");
            SetText("lblLicense", lang, "Commercial / industrial license — optional", "Licence commerciale — optionnel", "Ticari / sınai lisans — isteğe bağlı", "رقم الترخيص التجاري/الصناعي — اختياري");
            SetText("lblEmail", lang, "Email — optional", "E-mail — optionnel", "E-posta — isteğe bağlı", "البريد الإلكتروني — اختياري");
            SetText("lblWebsite", lang, "Website — optional", "Site web — optionnel", "Web sitesi — isteğe bağlı", "الموقع الإلكتروني (Website) — اختياري");
            SetText("lblAuto8", lang, "Phone — optional", "Téléphone — optionnel", "Telefon — isteğe bağlı", "الهاتف — اختياري");
            SetText("lblAuto9", lang, "Mobile — optional", "Mobile — optionnel", "Cep telefonu — isteğe bağlı", "الموبايل — اختياري");
            SetText("lblAuto10", lang, "Address line 1 — optional", "Adresse ligne 1 — optionnel", "Adres satırı 1 — isteğe bağlı", "العنوان السطر الأول — اختياري");
            SetText("lblAuto11", lang, "Address line 2 — optional", "Adresse ligne 2 — optionnel", "Adres satırı 2 — isteğe bağlı", "العنوان السطر الثاني — اختياري");
            SetText("lblCity", lang, "City — optional", "Ville — optionnel", "Şehir — isteğe bağlı", "المدينة — اختياري");
            SetText("lblCountry", lang, "Country — optional", "Pays — optionnel", "Ülke — isteğe bağlı", "الدولة — اختياري");
            SetText("lblAuto14", lang, "Notes (optional)", "Notes (optionnel)", "Notlar (isteğe bağlı)", "ملاحظات (اختياري)");
            SetText("lblAuto15", lang, "Fiscal year", "Exercice fiscal", "Mali yıl", "السنة المالية");
            SetText("lblAuto16", lang, "Set the fiscal year start and end dates.", "Définissez le début et la fin de l'exercice.", "Mali yılın başlangıç ve bitiş tarihlerini belirleyin.", "حدّد بداية ونهاية السنة المالية (كما في Sage وSAP). لا يُفضّل تغييرها لاحقاً دون مراجعة محاسبية.");
            SetText("lblAuto17", lang, "From date *", "Date de début *", "Başlangıç *", "من تاريخ *");
            SetText("lblAuto18", lang, "To date *", "Date de fin *", "Bitiş *", "إلى تاريخ *");
            SetText("lblAuto19", lang, "Currency, calendar & language", "Devise, calendrier et langue", "Para birimi, takvim ve dil", "العملة والتقويم واللغة");
            SetText("lblAuto20", lang, "Default currency *", "Devise par défaut *", "Varsayılan para birimi *", "العملة الافتراضية *");
            SetText("lblAuto21", lang, "Decimal places", "Décimales", "Ondalık basamak", "عدد المنازل بعد الفاصلة");
            SetText("lblAuto22", lang, "Calendar type", "Type de calendrier", "Takvim türü", "نوع التاريخ");
            SetText("lblAuto23", lang, "Number grouping", "Groupement des nombres", "Sayı gruplama", "تقسيم الأرقام");
            SetText("lblAuto24", lang, "Primary UI language", "Langue de l'interface", "Arayüz dili", "لغة الواجهة الأساسية");
            SetText("lblAuto25", lang, "First system administrator", "Premier administrateur", "İlk sistem yöneticisi", "مدير النظام الأول");
            SetText("lblAuto26", lang, "Create the first administrator account for this company.", "Créez le premier compte administrateur de cette société.", "Bu şirket için ilk yönetici hesabını oluşturun.", "أنشئ حساب المدير الأول للشركة (كما في Sage 100 وSAP B1).");
            SetText("lblAuto27", lang, "Username *", "Nom d'utilisateur *", "Kullanıcı adı *", "اسم المستخدم *");
            SetText("lblAuto28", lang, "Full name — optional", "Nom complet — optionnel", "Ad soyad — isteğe bağlı", "الاسم الكامل — اختياري");
            SetText("lblAuto29", lang, "Password *", "Mot de passe *", "Şifre *", "كلمة المرور *");
            SetText("lblAuto30", lang, "Confirm password *", "Confirmer le mot de passe *", "Şifreyi onayla *", "تأكيد كلمة المرور *");
            SetText("lblAuto31", lang, "Storage & backup", "Stockage et sauvegarde", "Depolama ve yedekleme", "التخزين والنسخ الاحتياطي");
            SetText("lblAuto32", lang, "Database path (managed) *", "Chemin de la base (géré) *", "Veritabanı yolu (yönetilen) *", "مسار قاعدة البيانات (إلزامي ومدار آلياً) *");
            SetText("lblAuto33", lang, "Alternate path — optional", "Chemin alternatif — optionnel", "Alternatif yol — isteğe bağlı", "مسار بديل — اختياري");
            SetText("lblAuto34", lang, "Backup path (managed) *", "Chemin de sauvegarde (géré) *", "Yedekleme yolu (yönetilen) *", "مسار النسخ الاحتياطي (إلزامي ومدار آلياً) *");
            SetText("lblAuto35", lang, "Additional backup — optional", "Sauvegarde additionnelle — optionnel", "Ek yedek — isteğe bağlı", "نسخ احتياطي إضافي — اختياري");
            SetText("lblAuto36", lang, "Frequency", "Fréquence", "Sıklık", "التكرار");
            SetText("lblAuto37", lang, "Backup time", "Heure de sauvegarde", "Yedekleme saati", "توقيت النسخ");

            try
            {
                if (chkAutoBackup != null)
                    chkAutoBackup.Content = lang switch
                    {
                        "en" => "Enable automatic backup",
                        "fr" => "Activer la sauvegarde automatique",
                        "tr" => "Otomatik yedeklemeyi etkinleştir",
                        _ => "تفعيل النسخ الاحتياطي الآلي"
                    };
            }
            catch { }

            // Refresh step title for current page
            var stepTitle = GetStepTitle(_currentStep, lang);
            txtStepTitle.Text = lang switch
            {
                "tr" => $"Adım {_currentStep} / {MaxStep} — {stepTitle}",
                "fr" => $"Étape {_currentStep} sur {MaxStep} — {stepTitle}",
                "en" => $"Step {_currentStep} of {MaxStep} — {stepTitle}",
                _ => $"الخطوة {_currentStep} من {MaxStep} — {stepTitle}"
            };
        }

        private void SetText(string controlName, string lang, string en, string fr, string tr, string ar)
        {
            try
            {
                if (FindName(controlName) is not System.Windows.Controls.TextBlock tb)
                    return;
                tb.Text = lang switch
                {
                    "en" => en,
                    "fr" => fr,
                    "tr" => tr,
                    _ => ar
                };
            }
            catch { }
        }

        #endregion

        #region Navigation & UI Updates

        private void UpdateStepUi()
        {
            var lang = ResolveWizardLanguage();
            var stepTitle = GetStepTitle(_currentStep, lang);
            txtStepTitle.Text = lang switch
            {
                "tr" => $"Adım {_currentStep} / {MaxStep} — {stepTitle}",
                "fr" => $"Étape {_currentStep} sur {MaxStep} — {stepTitle}",
                "en" => $"Step {_currentStep} of {MaxStep} — {stepTitle}",
                _ => $"الخطوة {_currentStep} من {MaxStep} — {stepTitle}"
            };


            btnBack.IsEnabled = _currentStep > MinStep && !_isSaving;
            btnNext.Visibility = _currentStep < MaxStep ? Visibility.Visible : Visibility.Collapsed;
            btnFinish.Visibility = _currentStep == MaxStep ? Visibility.Visible : Visibility.Collapsed;

            btnNext.IsEnabled = !_isSaving;
            btnFinish.IsEnabled = !_isSaving;

            Page1.Visibility = _currentStep == 1 ? Visibility.Visible : Visibility.Collapsed;
            Page2.Visibility = _currentStep == 2 ? Visibility.Visible : Visibility.Collapsed;
            PageFiscal.Visibility = _currentStep == 3 ? Visibility.Visible : Visibility.Collapsed;
            PageCurrency.Visibility = _currentStep == 4 ? Visibility.Visible : Visibility.Collapsed;
            PageAdmin.Visibility = _currentStep == 5 ? Visibility.Visible : Visibility.Collapsed;
            PageStorage.Visibility = _currentStep == 6 ? Visibility.Visible : Visibility.Collapsed;

            if (_currentStep != 5)
            {
                ClearAdminPasswordAvailabilityError();
            }
        }

        private void UpdateFiscalHint()
        {
            if (dpFiscalStart.SelectedDate is not DateTime start || dpFiscalEnd.SelectedDate is not DateTime end)
            {
                txtFiscalHint.Text = string.Empty;
                return;
            }

            var totalDays = (end.Date - start.Date).TotalDays + 1;
            var lang = ResolveWizardLanguage();
            if (totalDays > 0)
            {
                txtFiscalHint.Text = lang switch
                {
                    "en" => $"Fiscal year length: {totalDays:N0} days",
                    "fr" => $"Durée de l'exercice : {totalDays:N0} jours",
                    "tr" => $"Mali yıl süresi: {totalDays:N0} gün",
                    _ => $"إجمالي فترة السنة المالية: {totalDays:N0} يوماً"
                };
            }
            else
            {
                txtFiscalHint.Text = lang switch
                {
                    "en" => "Warning: end date must be after start date.",
                    "fr" => "Attention : la date de fin doit être postérieure à la date de début.",
                    "tr" => "Uyarı: bitiş tarihi başlangıçtan sonra olmalıdır.",
                    _ => "⚠️ خطأ: تاريخ النهاية يجب أن يكون بعد تاريخ البداية."
                };
            }
        }

        private void StopAutoProgressOnUserAction()
        {
            if (_isUserInteracted) return;

            _isUserInteracted = true;
            if (_autoProgressTimer.IsEnabled)
            {
                _autoProgressTimer.Stop();
            }
        }

        #endregion

        #region Event Handlers

        private void AutoProgressTimer_Tick(object? sender, EventArgs e)
        {
            if (_mode != StpWizMode.FirstRun || _isSaving || _isUserInteracted)
                return;

            if (_currentStep >= MaxStep)
            {
                _autoProgressTimer.Stop();
                return;
            }

            _currentStep++;
            UpdateStepUi();
        }

        private void BtnBack_Click(object sender, RoutedEventArgs e)
        {
            StopAutoProgressOnUserAction();

            if (_currentStep > MinStep)
            {
                _currentStep--;
                UpdateStepUi();
            }
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            StopAutoProgressOnUserAction();
            if (_isSaving)
                return;

            // Close through the normal closing pipeline. This preserves the FirstRun
            // exit confirmation and returns a non-success result to callers in NewCompany mode.
            Close();
        }

        private void StpWiz_PreviewKeyDown(object sender, KeyEventArgs e)
        {
            StopAutoProgressOnUserAction();

            if (e.Key == Key.Escape && !_isSaving)
            {
                e.Handled = true;
                Close();
            }
        }

        private async void BtnNext_Click(object sender, RoutedEventArgs e)
        {
            StopAutoProgressOnUserAction();

            if (!ValidateStep(_currentStep))
                return;

            if (_currentStep == 5 && !await ValidateAdminPasswordAvailabilityAsync())
            {
                txtAdminPassword.Focus();
                return;
            }

            if (_currentStep < MaxStep)
            {
                _currentStep++;

                if (_currentStep == 6 && _mode == StpWizMode.NewCompany)
                    await PopulateManagedStoragePathsAsync();

                UpdateStepUi();
            }
        }

        private async void BtnFinish_Click(object sender, RoutedEventArgs e)
        {
            StopAutoProgressOnUserAction();
            await FinishWizardAsync();
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            if (_isSaving)
            {
                e.Cancel = true;
                // رسالة هادئة وليست مخيفة
                MessageBox.Show(
                    Msg(
                        "جاري حفظ بيانات الشركة، الرجاء الانتظار لحظة.",
                        "Saving company data, please wait a moment.",
                        "Enregistrement des données de la société, veuillez patienter.",
                        "Şirket verileri kaydediliyor, lütfen bekleyin."),
                    "ShouTech ERP",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            if (!CompletedSuccessfully && _mode == StpWizMode.FirstRun)
            {
                var response = MessageBox.Show(
                    Msg(
                        "لم يتم إكمال المعالج بعد. هل تريد الخروج؟",
                        "The wizard is not complete yet. Do you want to exit?",
                        "L'assistant n'est pas encore terminé. Voulez-vous quitter ?",
                        "Sihirbaz henüz tamamlanmadı. Çıkmak istiyor musunuz?"),
                    Msg("تأكيد الخروج", "Confirm exit", "Confirmer la sortie", "Çıkışı onayla"),
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);

                if (response == MessageBoxResult.No)
                {
                    e.Cancel = true;
                    return;
                }
            }

            _autoProgressTimer?.Stop();
            base.OnClosing(e);
        }

        #endregion

        #region Validation Logic

        private bool ValidateStep(int stepIndex)
        {
            switch (stepIndex)
            {
                case 2:
                    // الحقول الإلزامية في بيانات الشركة: الاسم المحلي فقط.
                    // بقية بيانات الهوية والاتصال والعنوان اختيارية ويمكن استكمالها لاحقاً.
                    if (string.IsNullOrWhiteSpace(txtCompanyName.Text))
                    {
                        ShowSoftWarning(Msg(
                            "يرجى إدخال اسم الشركة.",
                            "Please enter the company name.",
                            "Veuillez saisir le nom de la société.",
                            "Lütfen şirket adını girin."), txtCompanyName);
                        return false;
                    }

                    if (!string.IsNullOrWhiteSpace(txtEmail.Text) && !IsValidEmail(txtEmail.Text.Trim()))
                    {
                        ShowSoftWarning(Msg(
                            "صيغة البريد الإلكتروني غير صحيحة.",
                            "Invalid email format.",
                            "Format d'e-mail non valide.",
                            "E-posta biçimi geçersiz."), txtEmail);
                        return false;
                    }
                    break;

                case 3:
                    if (dpFiscalStart.SelectedDate is not DateTime start || dpFiscalEnd.SelectedDate is not DateTime end)
                    {
                        ShowSoftWarning(Msg(
                            "يرجى تحديد تاريخي بداية ونهاية السنة المالية.",
                            "Please select the fiscal year start and end dates.",
                            "Veuillez sélectionner les dates de début et de fin de l'exercice.",
                            "Lütfen mali yıl başlangıç ve bitiş tarihlerini seçin."));
                        return false;
                    }

                    if (end.Date <= start.Date)
                    {
                        ShowSoftWarning(Msg(
                            "تاريخ النهاية يجب أن يكون بعد تاريخ البداية.",
                            "The end date must be after the start date.",
                            "La date de fin doit être postérieure à la date de début.",
                            "Bitiş tarihi başlangıç tarihinden sonra olmalıdır."));
                        return false;
                    }
                    break;

                case 4:
                    if (cmbCurrency.SelectedItem is not ArabCurr)
                    {
                        ShowSoftWarning(Msg(
                            "يرجى اختيار العملة الافتراضية.",
                            "Please select the default currency.",
                            "Veuillez sélectionner la devise par défaut.",
                            "Lütfen varsayılan para birimini seçin."));
                        return false;
                    }
                    break;

                case 5:
                    if (string.IsNullOrWhiteSpace(txtAdminUser.Text))
                    {
                        ShowSoftWarning(Msg(
                            "يرجى إدخال اسم المستخدم.",
                            "Please enter the username.",
                            "Veuillez saisir le nom d'utilisateur.",
                            "Lütfen kullanıcı adını girin."), txtAdminUser);
                        return false;
                    }

                    if (string.IsNullOrEmpty(txtAdminPassword.Password))
                    {
                        ShowSoftWarning(Msg(
                            "يرجى إدخال كلمة المرور.",
                            "Please enter the password.",
                            "Veuillez saisir le mot de passe.",
                            "Lütfen şifreyi girin."), txtAdminPassword);
                        return false;
                    }

                    if (!string.Equals(txtAdminPassword.Password, txtAdminPasswordConfirm.Password, StringComparison.Ordinal))
                    {
                        ShowSoftWarning(Msg(
                            "كلمة المرور وتأكيدها غير متطابقين.",
                            "Password and confirmation do not match.",
                            "Le mot de passe et sa confirmation ne correspondent pas.",
                            "Şifre ve onayı eşleşmiyor."));
                        return false;
                    }
                    break;

                case 6:
                    // هذان المساران إلزاميان، لكنهما مُداران بالكامل بواسطة ShouTech
                    // وليسا حقول إدخال للمستخدم. نتحقق من أن النظام ولّدهما بشكل صحيح.
                    if (string.IsNullOrWhiteSpace(txtDbPath.Text) || !IsValidPath(txtDbPath.Text.Trim()))
                    {
                        ShowSoftWarning(Msg(
                            "تعذر تحديد مسار قاعدة البيانات الذي يديره ShouTech.",
                            "ShouTech could not determine the managed database path.",
                            "ShouTech n’a pas pu déterminer le chemin géré de la base de données.",
                            "ShouTech tarafından yönetilen veritabanı yolu belirlenemedi."), txtDbPath);
                        return false;
                    }

                    if (string.IsNullOrWhiteSpace(txtBkpPath.Text) || !IsValidPath(txtBkpPath.Text.Trim()))
                    {
                        ShowSoftWarning(Msg(
                            "تعذر تحديد مسار النسخ الاحتياطي الذي يديره ShouTech.",
                            "ShouTech could not determine the managed backup path.",
                            "ShouTech n’a pas pu déterminer le chemin géré des sauvegardes.",
                            "ShouTech tarafından yönetilen yedekleme yolu belirlenemedi."), txtBkpPath);
                        return false;
                    }
                    break;
            }

            return true;
        }

        private bool ValidateAllSteps()
        {
            for (var i = MinStep; i <= MaxStep; i++)
            {
                if (!ValidateStep(i))
                {
                    _currentStep = i;
                    UpdateStepUi();
                    return false;
                }
            }
            return true;
        }

        #endregion

        #region Core Business Logic (Enterprise UX)

        private async Task FinishWizardAsync()
        {
            if (_isSaving) return;

            if (!ValidateAllSteps()) return;
            if (!await ValidateAdminPasswordAvailabilityAsync())
            {
                _currentStep = 5;
                UpdateStepUi();
                txtAdminPassword.Focus();
                return;
            }

            try
            {
                SetBusyState(true, "جاري إنشاء الشركة...");

                var request = BuildRequest();

                // تسجيل بداية العملية للمطور
                AppHost.Logging.LogInfo("CompanyCreation", $"بدء إنشاء شركة: {request.CompanyNameAr}");

                // محاولة إنشاء الشركة عبر الخدمة
                var result = await AppHost.CompanyCreation.CreateAsync(request);

                // -----------------------------------------------------------------
                // ✅ منطق Enterprise UX: نجاح أو فشل، نتعامل معه بهدوء
                // -----------------------------------------------------------------
                if (result.Success)
                {
                    // تسجيل النجاح
                    AppHost.Logging.LogInfo("CompanyCreation", $"نجاح إنشاء الشركة: {result.CompanyCode}");

                    CompletedSuccessfully = true;
                    CreatedCompanyCode = result.CompanyCode;

                    // عرض رسالة النجاح (الوحيدة التي يراها المستخدم)
                    MessageBox.Show(
                        Msg(
                            $"تم إنشاء الشركة والمستخدم بنجاح!\n\n• الشركة: {result.CompanyNameAr}\n• كود الشركة: {result.CompanyCode}\n• حساب المدير: {request.AdminUsername}",
                            $"Company and administrator created successfully!\n\n• Company: {result.CompanyNameAr}\n• Code: {result.CompanyCode}\n• Admin: {request.AdminUsername}",
                            $"Société et administrateur créés avec succès !\n\n• Société : {result.CompanyNameAr}\n• Code : {result.CompanyCode}\n• Admin : {request.AdminUsername}",
                            $"Şirket ve yönetici başarıyla oluşturuldu!\n\n• Şirket: {result.CompanyNameAr}\n• Kod: {result.CompanyCode}\n• Yönetici: {request.AdminUsername}"),
                        "ShouTech ERP",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information);

                    // الانتقال إلى شاشة اختيار الشركات
                    CompleteWizard();
                }
                else
                {
                    AppHost.Logging.LogWarning("CompanyCreation", 
                        $"فشل إنشاء الشركة: {result.Message}");

                    MessageBox.Show(
                        Msg(
                            $"لم يتم إنشاء الشركة.\n\n{result.Message}\n\nراجع البيانات أو إعدادات الاتصال ثم حاول مرة أخرى.",
                            $"Company was not created.\n\n{result.Message}\n\nReview the data or connection settings and try again.",
                            $"La société n'a pas été créée.\n\n{result.Message}\n\nVérifiez les données ou les paramètres de connexion, puis réessayez.",
                            $"Şirket oluşturulamadı.\n\n{result.Message}\n\nVerileri veya bağlantı ayarlarını kontrol edip tekrar deneyin."),
                        "ShouTech ERP",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning);
                }
            }
            catch (Exception ex)
            {
                AppHost.Logging.LogError("CompanyCreation", 
                    $"استثناء أثناء إنشاء الشركة: {ex.Message}", ex);

                MessageBox.Show(
                    Msg(
                        "تعذر إنشاء الشركة بسبب خطأ غير متوقع. تم تسجيل التفاصيل للمراجعة.",
                        "Company could not be created due to an unexpected error. Details were logged for review.",
                        "Impossible de créer la société en raison d'une erreur inattendue. Les détails ont été enregistrés.",
                        "Beklenmeyen bir hata nedeniyle şirket oluşturulamadı. Ayrıntılar incelenemek üzere kaydedildi."),
                    "ShouTech ERP",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }
            finally
            {
                // 🔓 ضمان تحرير حالة الحجز حتى لو حدث أي شيء
                SetBusyState(false);
            }
        }

        /// <summary>
        /// إكمال المعالج والانتقال إلى شاشة اختيار الشركات
        /// هذه الشاشة ستتعامل مع أي حالة (وجود شركات أو عدمها) بهدوء
        /// </summary>
        private void CompleteWizard()
        {
            if (_mode == StpWizMode.NewCompany)
            {
                Close();
                return;
            }

            // في التشغيل الأول، نفتح نافذة اختيار الشركات
            // إذا لم توجد شركات، ستفتح المعالج مرة أخرى (دورة هادئة)
            var companyWindow = new ComWin();
            System.Windows.Application.Current.MainWindow = companyWindow;
            companyWindow.Show();
            Close();
        }

        private NewCoReq BuildRequest()
        {
            var currency = cmbCurrency.SelectedItem as ArabCurr ?? ArabCurr.All[0];
            var decimalPlaces = int.TryParse((cmbDecimalPlaces.SelectedItem as ComboBoxItem)?.Content?.ToString(), out var dp) ? dp : 2;
            var langCode = (cmbLanguageCode.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "ar-SY";

            return new NewCoReq
            {
                CompanyNameAr = txtCompanyName.Text.Trim(),
                CompanyNameEn = txtCompanyNameEn.Text.Trim(),
                TaxNumber = txtTaxNumber.Text.Trim(),
                License = txtLicense.Text.Trim(),
                Email = txtEmail.Text.Trim(),
                Website = txtWebsite.Text.Trim(),
                Phone = txtPhone.Text.Trim(),
                Mobile = txtMobile.Text.Trim(),
                AddressLine1 = txtAddressLine1.Text.Trim(),
                AddressLine2 = txtAddressLine2.Text.Trim(),
                City = txtCity.Text.Trim(),
                Country = txtCountry.Text.Trim(),
                Notes = txtNotes.Text.Trim(),
                FiscalYearStart = dpFiscalStart.SelectedDate ?? new DateTime(DateTime.Today.Year, 1, 1),
                FiscalYearEnd = dpFiscalEnd.SelectedDate ?? new DateTime(DateTime.Today.Year, 12, 31),
                CurrencyCode = currency.Code,
                DecimalPlaces = decimalPlaces,
                CalendarType = (cmbCalendarType.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "ميلادي",
                NumberGrouping = (cmbNumberGrouping.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "3-3-3",
                LanguageCode = langCode,
                AdminUsername = txtAdminUser.Text.Trim(),
                AdminPassword = txtAdminPassword.Password,
                AdminFullName = string.IsNullOrWhiteSpace(txtAdminFullName.Text)
                    ? txtAdminUser.Text.Trim()
                    : txtAdminFullName.Text.Trim(),
                DbPath = txtDbPath.Text.Trim(),
                AltDbPath = txtAltDbPath.Text.Trim(),
                BackupPath = txtBkpPath.Text.Trim(),
                AltBackupPath = txtAltBkpPath.Text.Trim(),
                AutoBackup = chkAutoBackup.IsChecked == true,
                BackupSchedule = (cmbBackupSchedule.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "يومي",
                BackupTime = txtBackupTime.Text.Trim()
            };
        }

        #endregion

        #region Helper Methods


        private async Task PopulateManagedStoragePathsAsync()
        {
            if (_mode != StpWizMode.NewCompany)
                return;

            try
            {
                var companies = await CoLocalStore.LoadAllAsync().ConfigureAwait(true);
                var nextNumber = companies
                    .Select(c => int.TryParse(c.Code, out var n) ? n : 0)
                    .DefaultIfEmpty(0)
                    .Max() + 1;

                var code = nextNumber.ToString("000", System.Globalization.CultureInfo.InvariantCulture);
                var databaseDirectory = AppSettings.Current.DatabaseDirectory;
                var backupDirectory = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "ShouTech", "ERP", "Backups", $"ShouTech{code}");

                Directory.CreateDirectory(databaseDirectory);
                Directory.CreateDirectory(backupDirectory);

                txtDbPath.Text = Path.Combine(databaseDirectory, $"ShouTech{code}.db");
                txtBkpPath.Text = backupDirectory;
            }
            catch (Exception ex)
            {
                AppHost.Logging.LogWarning("CompanyWizard", $"تعذر توليد مسارات التخزين المُدارة: {ex.Message}");
            }
        }

        private void SetBusyState(bool isBusy, string statusMessage = "")
        {
            _isSaving = isBusy;
            Mouse.OverrideCursor = isBusy ? Cursors.Wait : null;

            btnFinish.Content = isBusy
                ? statusMessage
                : ResolveWizardLanguage() switch
                {
                    "en" => "Finish",
                    "fr" => "Terminer",
                    "tr" => "Bitir",
                    _ => "إنهاء"
                };
            UpdateStepUi();
        }

        private void ClearPasswordFields()
        {
            txtAdminPassword.Password = string.Empty;
            txtAdminPasswordConfirm.Password = string.Empty;
            ClearAdminPasswordAvailabilityError();
        }

        private async void TxtAdminUser_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_currentStep != 5)
                return;

            await ValidateAdminPasswordAvailabilityAsync();
        }

        private async void TxtAdminPassword_PasswordChanged(object sender, RoutedEventArgs e)
        {
            if (_currentStep != 5)
                return;

            await ValidateAdminPasswordAvailabilityAsync();
        }

        private async Task<bool> ValidateAdminPasswordAvailabilityAsync()
        {
            if (_isCheckingPasswordAvailability)
                return string.IsNullOrWhiteSpace(txtAdminPasswordAvailabilityError.Text);

            var username = txtAdminUser.Text.Trim();
            var password = txtAdminPassword.Password;

            if (string.IsNullOrWhiteSpace(username) || string.IsNullOrEmpty(password))
            {
                ClearAdminPasswordAvailabilityError();
                return true;
            }

            _isCheckingPasswordAvailability = true;
            try
            {
                var owner = await CoLocalStore.FindPasswordOwnerAsync(password);
                if (owner == null || string.Equals(owner.AdminUsername, username, StringComparison.OrdinalIgnoreCase))
                {
                    ClearAdminPasswordAvailabilityError();
                    return true;
                }

                txtAdminPasswordAvailabilityError.Text = Msg(
                    $"كلمة المرور غير متاحة. هي مستخدمة من المستخدم «{owner.AdminUsername}».",
                    $"Password is not available. It is already used by user «{owner.AdminUsername}».",
                    $"Mot de passe indisponible. Déjà utilisé par « {owner.AdminUsername} ».",
                    $"Şifre kullanılamıyor. «{owner.AdminUsername}» kullanıcısı tarafından kullanılıyor.");
                txtAdminPasswordAvailabilityError.Visibility = Visibility.Visible;
                return false;
            }
            finally
            {
                _isCheckingPasswordAvailability = false;
            }
        }

        private void ClearAdminPasswordAvailabilityError()
        {
            txtAdminPasswordAvailabilityError.Text = string.Empty;
            txtAdminPasswordAvailabilityError.Visibility = Visibility.Collapsed;
        }

        /// <summary>
        /// رسائل تحذير ناعمة (بدون أيقونات خطأ حمراء) لتجنب تخويف المستخدم
        /// </summary>
        private static void ShowSoftWarning(string message, Control? controlToFocus = null)
        {
            MessageBox.Show(message, "ShouTech ERP", MessageBoxButton.OK, MessageBoxImage.Information);
            controlToFocus?.Focus();
        }

        private static bool IsValidEmail(string email)
        {
            return Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.IgnoreCase);
        }

        private static bool IsValidPath(string path)
        {
            try
            {
                var fullPath = Path.GetFullPath(path);
                return Path.IsPathRooted(fullPath);
            }
            catch
            {
                return false;
            }
        }

        #endregion
    }
}