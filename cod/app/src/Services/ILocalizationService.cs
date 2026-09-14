// ========================================================================
// FILE: cod/app/src/Services/LocalizationService.cs
// ========================================================================

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Threading;

namespace ShouTech.App.Services
{
    /// <summary>
    /// واجهة خدمة الترجمة - تدعم 4 لغات
    /// </summary>
    public interface ILocalizationService
    {
        /// <summary>
        /// الحصول على النص المترجم حسب المفتاح
        /// </summary>
        string GetString(string key);
        
        /// <summary>
        /// الحصول على النص المترجم حسب المفتاح مع قيمة افتراضية
        /// </summary>
        string GetString(string key, string defaultValue);
        
        /// <summary>
        /// تعيين اللغة الحالية
        /// </summary>
        void SetLanguage(string languageCode);
        
        /// <summary>
        /// الحصول على اللغة الحالية
        /// </summary>
        string GetCurrentLanguage();
        
        /// <summary>
        /// حدث تغيير اللغة
        /// </summary>
        event EventHandler? LanguageChanged;
        
        /// <summary>
        /// الحصول على قائمة اللغات المتاحة
        /// </summary>
        List<string> GetAvailableLanguages();
        
        /// <summary>
        /// تحميل الموارد (للتوافق مع الإصدارات السابقة)
        /// </summary>
        void LoadResources();
    }

    /// <summary>
    /// خدمة الترجمة - تدعم العربية، الإنجليزية، الفرنسية، التركية
    /// </summary>
    public class LocalizationService : ILocalizationService
    {
        private Dictionary<string, string> _resources = new();
        private string _currentLanguage = "en";
        private readonly string _resourcesPath;
        private readonly List<string> _availableLanguages = new() { "ar", "en", "fr", "tr" };

        public event EventHandler? LanguageChanged;

        public LocalizationService()
        {
            // تحديد مسار ملفات اللغة
            var basePath = AppDomain.CurrentDomain.BaseDirectory;
            
            // محاولة عدة مسارات
            string[] possiblePaths = {
                Path.Combine(basePath, "Resources", "Lang"),
                Path.Combine(basePath, "..", "..", "..", "Resources", "Lang"),
                Path.Combine(basePath, "..", "..", "Resources", "Lang"),
                @"D:\erp\shoutech_erp_v9\cod\app\src\Resources\Lang"
            };

            _resourcesPath = null!;
            foreach (var path in possiblePaths)
            {
                if (Directory.Exists(path))
                {
                    _resourcesPath = path;
                    break;
                }
            }

            // إذا لم يتم العثور على المسار، استخدم المسار الأول
            if (string.IsNullOrEmpty(_resourcesPath))
            {
                _resourcesPath = possiblePaths[0];
                Directory.CreateDirectory(_resourcesPath);
            }

            System.Diagnostics.Debug.WriteLine($"📁 Resources Path: {_resourcesPath}");
            
            // تحميل اللغة الافتراضية
            LoadResources();
        }

        public string GetString(string key)
        {
            return _resources.TryGetValue(key, out var value) ? value : key;
        }

        public string GetString(string key, string defaultValue)
        {
            return _resources.TryGetValue(key, out var value) ? value : defaultValue;
        }

        public void SetLanguage(string languageCode)
        {
            if (string.IsNullOrEmpty(languageCode) || languageCode == _currentLanguage)
                return;

            if (!_availableLanguages.Contains(languageCode))
                return;

            _currentLanguage = languageCode;
            LoadResources();
            
            // تحديث الثقافة
            try
            {
                var culture = new System.Globalization.CultureInfo(languageCode);
                Thread.CurrentThread.CurrentCulture = culture;
                Thread.CurrentThread.CurrentUICulture = culture;
                System.Globalization.CultureInfo.DefaultThreadCurrentCulture = culture;
                System.Globalization.CultureInfo.DefaultThreadCurrentUICulture = culture;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Culture error: {ex.Message}");
            }

            System.Diagnostics.Debug.WriteLine($"🌐 Language changed to: {languageCode}");
            LanguageChanged?.Invoke(this, EventArgs.Empty);
        }

        public string GetCurrentLanguage() => _currentLanguage;

        public List<string> GetAvailableLanguages() => _availableLanguages;

        public void LoadResources()
        {
            LoadLanguage(_currentLanguage);
        }

        private void LoadLanguage(string languageCode)
        {
            try
            {
                // تنسيق اسم الملف: Ar.json, En.json, Fr.json, Tr.json
                var fileName = languageCode switch
                {
                    "ar" => "Ar.json",
                    "en" => "En.json",
                    "fr" => "Fr.json",
                    "tr" => "Tr.json",
                    _ => $"{char.ToUpper(languageCode[0], CultureInfo.InvariantCulture)}{languageCode.Substring(1)}.json"
                };
                
                var filePath = Path.Combine(_resourcesPath, fileName);
                
                if (!File.Exists(filePath))
                {
                    System.Diagnostics.Debug.WriteLine($"⚠️ Language file not found: {filePath}");
                    CreateDefaultLanguageFile(filePath, languageCode);
                }

                var json = File.ReadAllText(filePath);
                var data = JsonSerializer.Deserialize<Dictionary<string, object>>(json);
                
                if (data != null)
                {
                    _resources.Clear();
                    FlattenDictionary(data, "");
                    System.Diagnostics.Debug.WriteLine($"✅ Loaded {_resources.Count} resources from {languageCode}");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"❌ Error loading language: {ex.Message}");
            }
        }

        private static void CreateDefaultLanguageFile(string filePath, string languageCode)
        {
            try
            {
                var defaultContent = languageCode switch
                {
                    "ar" => @"{
  ""Application"": {
    ""Title"": ""شو تيك إي آر بي"",
    ""Subtitle"": ""منصة إدارة المؤسسات المتكاملة"",
    ""Version"": ""الإصدار"",
    ""Ready"": ""جاهز""
  },
  ""Menu"": {
    ""File"": ""ملف"",
    ""Inventory"": ""المستودعات"",
    ""Accounts"": ""الحسابات"",
    ""Reports"": ""تقارير"",
    ""Tools"": ""أدوات"",
    ""Help"": ""مساعدة"",
    ""Exit"": ""خروج""
  },
  ""Dashboard"": {
    ""Title"": ""لوحة القيادة"",
    ""Welcome"": ""مرحباً بك""
  },
  ""Status"": {
    ""Ready"": ""جاهز"",
    ""Connected"": ""متصل""
  },
  ""Buttons"": {
    ""Save"": ""حفظ"",
    ""Cancel"": ""إلغاء"",
    ""Delete"": ""حذف"",
    ""Edit"": ""تعديل"",
    ""Add"": ""إضافة"",
    ""Search"": ""بحث""
  }
}",
                    "en" => @"{
  ""Application"": {
    ""Title"": ""ShouTech ERP"",
    ""Subtitle"": ""Integrated Enterprise Management Platform"",
    ""Version"": ""Version"",
    ""Ready"": ""Ready""
  },
  ""Menu"": {
    ""File"": ""File"",
    ""Inventory"": ""Inventory"",
    ""Accounts"": ""Accounts"",
    ""Reports"": ""Reports"",
    ""Tools"": ""Tools"",
    ""Help"": ""Help"",
    ""Exit"": ""Exit""
  },
  ""Dashboard"": {
    ""Title"": ""Dashboard"",
    ""Welcome"": ""Welcome""
  },
  ""Status"": {
    ""Ready"": ""Ready"",
    ""Connected"": ""Connected""
  },
  ""Buttons"": {
    ""Save"": ""Save"",
    ""Cancel"": ""Cancel"",
    ""Delete"": ""Delete"",
    ""Edit"": ""Edit"",
    ""Add"": ""Add"",
    ""Search"": ""Search""
  }
}",
                    "fr" => @"{
  ""Application"": {
    ""Title"": ""ShouTech ERP"",
    ""Subtitle"": ""Plateforme de Gestion d'Entreprise Intégrée"",
    ""Version"": ""Version"",
    ""Ready"": ""Prêt""
  },
  ""Menu"": {
    ""File"": ""Fichier"",
    ""Inventory"": ""Inventaire"",
    ""Accounts"": ""Comptes"",
    ""Reports"": ""Rapports"",
    ""Tools"": ""Outils"",
    ""Help"": ""Aide"",
    ""Exit"": ""Quitter""
  },
  ""Dashboard"": {
    ""Title"": ""Tableau de Bord"",
    ""Welcome"": ""Bienvenue""
  },
  ""Status"": {
    ""Ready"": ""Prêt"",
    ""Connected"": ""Connecté""
  },
  ""Buttons"": {
    ""Save"": ""Enregistrer"",
    ""Cancel"": ""Annuler"",
    ""Delete"": ""Supprimer"",
    ""Edit"": ""Modifier"",
    ""Add"": ""Ajouter"",
    ""Search"": ""Rechercher""
  }
}",
                    "tr" => @"{
  ""Application"": {
    ""Title"": ""ShouTech ERP"",
    ""Subtitle"": ""Entegre Kurumsal Yönetim Platformu"",
    ""Version"": ""Sürüm"",
    ""Ready"": ""Hazır""
  },
  ""Menu"": {
    ""File"": ""Dosya"",
    ""Inventory"": ""Envanter"",
    ""Accounts"": ""Hesaplar"",
    ""Reports"": ""Raporlar"",
    ""Tools"": ""Araçlar"",
    ""Help"": ""Yardım"",
    ""Exit"": ""Çıkış""
  },
  ""Dashboard"": {
    ""Title"": ""Yönetici Paneli"",
    ""Welcome"": ""Hoş Geldiniz""
  },
  ""Status"": {
    ""Ready"": ""Hazır"",
    ""Connected"": ""Bağlı""
  },
  ""Buttons"": {
    ""Save"": ""Kaydet"",
    ""Cancel"": ""İptal"",
    ""Delete"": ""Sil"",
    ""Edit"": ""Düzenle"",
    ""Add"": ""Ekle"",
    ""Search"": ""Ara""
  }
}",
                    _ => @"{
  ""Application"": {
    ""Title"": ""ShouTech ERP""
  },
  ""Menu"": {
    ""File"": ""File"",
    ""Exit"": ""Exit""
  }
}"
                };
                
                File.WriteAllText(filePath, defaultContent);
                System.Diagnostics.Debug.WriteLine($"📝 Created default language file: {filePath}");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"❌ Error creating default file: {ex.Message}");
            }
        }

        private void FlattenDictionary(Dictionary<string, object> dict, string prefix)
        {
            foreach (var kvp in dict)
            {
                var key = string.IsNullOrEmpty(prefix) ? kvp.Key : $"{prefix}.{kvp.Key}";
                
                if (kvp.Value is JsonElement jsonElement)
                {
                    if (jsonElement.ValueKind == JsonValueKind.Object)
                    {
                        var nested = JsonSerializer.Deserialize<Dictionary<string, object>>(jsonElement.GetRawText());
                        if (nested != null)
                        {
                            FlattenDictionary(nested, key);
                        }
                    }
                    else if (jsonElement.ValueKind == JsonValueKind.String)
                    {
                        _resources[key] = jsonElement.GetString() ?? key;
                    }
                    else
                    {
                        _resources[key] = jsonElement.ToString();
                    }
                }
                else if (kvp.Value is string str)
                {
                    _resources[key] = str;
                }
                else if (kvp.Value is Dictionary<string, object> nestedDict)
                {
                    FlattenDictionary(nestedDict, key);
                }
            }
        }
    }
}