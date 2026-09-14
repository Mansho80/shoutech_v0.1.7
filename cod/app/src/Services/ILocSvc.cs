// ========================================================================
// FILE: cod/app/src/Services/LocSvc.cs
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
    public interface ILocSvc
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
    public class LocSvc : ILocSvc
    {
        private Dictionary<string, string> _resources = new();
        private Dictionary<string, string> _arabicLabelToKey = new(StringComparer.Ordinal);
        private string _currentLanguage = "en";
        private readonly string _resourcesPath;
        private readonly List<string> _availableLanguages = new() { "ar", "en", "fr", "tr" };

        public event EventHandler? LanguageChanged;

        public LocSvc()
        {
            _resourcesPath = ResolveResourcesPath();
            BuildArabicLabelIndex();
            LoadResources();
        }

        public bool TryResolveKeyFromArabicLabel(string? label, out string key)
        {
            key = string.Empty;
            if (string.IsNullOrWhiteSpace(label))
                return false;

            var trimmed = label.Trim();
            if (_arabicLabelToKey.TryGetValue(trimmed, out key!))
                return true;

            var stripped = StripLeadingEmoji(trimmed);
            if (!string.IsNullOrWhiteSpace(stripped) && _arabicLabelToKey.TryGetValue(stripped.Trim(), out key!))
                return true;

            foreach (var prefix in ReportLabelPrefixes)
            {
                if (!trimmed.StartsWith(prefix, StringComparison.Ordinal))
                    continue;

                var withoutPrefix = trimmed[prefix.Length..].Trim();
                if (_arabicLabelToKey.TryGetValue(withoutPrefix, out key!))
                    return true;
            }

            return false;
        }

        private static readonly string[] ReportLabelPrefixes = { "تقرير ", "تقارير " };

        private static string ResolveResourcesPath()
        {
            var basePath = AppDomain.CurrentDomain.BaseDirectory;
            string[] candidates =
            {
                Path.Combine(basePath, "Resources", "Lang"),
                Path.GetFullPath(Path.Combine(basePath, "..", "..", "..", "Resources", "Lang")),
                Path.GetFullPath(Path.Combine(basePath, "..", "..", "Resources", "Lang"))
            };

            foreach (var path in candidates)
            {
                if (Directory.Exists(path))
                    return path;
            }

            var fallback = candidates[0];
            Directory.CreateDirectory(fallback);
            return fallback;
        }

        private void BuildArabicLabelIndex()
        {
            _arabicLabelToKey.Clear();
            var filePath = Path.Combine(_resourcesPath, "Ar.json");
            if (!File.Exists(filePath))
                return;

            try
            {
                var json = File.ReadAllText(filePath);
                var data = JsonSerializer.Deserialize<Dictionary<string, object>>(json);
                if (data == null)
                    return;

                var flat = new Dictionary<string, string>();
                FlattenToDictionary(data, string.Empty, flat);

                foreach (var pair in flat)
                {
                    if (!string.IsNullOrWhiteSpace(pair.Value) && !_arabicLabelToKey.ContainsKey(pair.Value))
                        _arabicLabelToKey[pair.Value] = pair.Key;
                }
            }
            catch (Exception)
            {
                // Arabic label index is optional for runtime localization.
            }
        }

        private static string StripLeadingEmoji(string value)
        {
            var i = 0;
            while (i < value.Length && !char.IsLetter(value[i]) && !char.IsDigit(value[i]))
                i++;

            return i < value.Length ? value[i..].Trim() : value.Trim();
        }

        private static void FlattenToDictionary(Dictionary<string, object> dict, string prefix, Dictionary<string, string> target)
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
                            FlattenToDictionary(nested, key, target);
                    }
                    else if (jsonElement.ValueKind == JsonValueKind.String)
                    {
                        target[key] = jsonElement.GetString() ?? key;
                    }
                }
                else if (kvp.Value is string str)
                {
                    target[key] = str;
                }
                else if (kvp.Value is Dictionary<string, object> nestedDict)
                {
                    FlattenToDictionary(nestedDict, key, target);
                }
            }
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
            if (string.IsNullOrWhiteSpace(languageCode))
                return;

            var normalized = languageCode.Trim().ToLowerInvariant();
            if (normalized.Contains('-'))
                normalized = normalized.Split('-')[0];
            if (normalized.Length > 2)
                normalized = normalized[..2];

            if (!_availableLanguages.Contains(normalized))
                return;

            if (normalized == _currentLanguage)
            {
                try { LanguageChanged?.Invoke(this, EventArgs.Empty); } catch { }
                return;
            }

            try
            {
                _currentLanguage = normalized;
                LoadResources();

                // Always apply culture with the normalized 2-letter code (fr / tr / ar / en).
                try
                {
                    var culture = CultureInfo.GetCultureInfo(normalized);
                    Thread.CurrentThread.CurrentCulture = culture;
                    Thread.CurrentThread.CurrentUICulture = culture;
                    CultureInfo.DefaultThreadCurrentCulture = culture;
                    CultureInfo.DefaultThreadCurrentUICulture = culture;
                }
                catch (CultureNotFoundException)
                {
                    // Keep current culture if the requested code is invalid on this OS.
                }
            }
            catch (Exception)
            {
                // Language switch must never crash the host process.
            }

            try { LanguageChanged?.Invoke(this, EventArgs.Empty); } catch { }
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
                    CreateDefaultLanguageFile(filePath, languageCode);
                    if (!File.Exists(filePath))
                    {
                        // Fallback to English packaged/default resources — never leave empty.
                        var enPath = Path.Combine(_resourcesPath, "En.json");
                        if (File.Exists(enPath))
                            filePath = enPath;
                        else
                            return;
                    }
                }

                var json = File.ReadAllText(filePath);
                var data = JsonSerializer.Deserialize<Dictionary<string, object>>(json);
                
                if (data != null)
                {
                    _resources.Clear();
                    FlattenDictionary(data, "");
                }
            }
            catch (Exception)
            {
                // Keep previously loaded resources if reload fails.
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
            }
            catch (Exception)
            {
                // Non-fatal: caller will retry with empty resources.
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