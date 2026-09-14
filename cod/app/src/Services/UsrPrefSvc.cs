// ========================================================================
// FILE: Services/UsrPrefSvc.cs
// PROJECT: SHOUTECH ERP V10
// FRAMEWORK: .NET 8.0 / C# 12 / WPF
// PURPOSE: Enterprise User Preferences Service
// ========================================================================

#nullable enable

using System;
using System.Windows;
using ShouTech.App.Configuration;

namespace ShouTech.App.Services;

/// <summary>
/// خدمة مركزية لإدارة تفضيلات المستخدم.
///
/// المسؤوليات:
/// - تحميل التفضيلات.
/// - التحقق والتطبيع.
/// - تطبيق إعدادات النافذة.
/// - حفظ حالة النافذة.
/// - تغيير اللغة.
/// - تغيير الثيم.
/// - إعادة الإعدادات للوضع الافتراضي.
///
/// Enterprise User Preferences Service.
/// </summary>
public sealed class UsrPrefSvc
{
    // ====================================================================
    // SYNCHRONIZATION
    // ====================================================================

    private readonly object _sync = new();

    // ====================================================================
    // STATE
    // ====================================================================

    private UsrPref _preferences;

    // ====================================================================
    // CONSTRUCTOR
    // ====================================================================

    /// <summary>
    /// إنشاء خدمة تفضيلات المستخدم وتحميل التفضيلات الحالية.
    /// </summary>
    public UsrPrefSvc()
    {
        _preferences = UsrPref.Load();
        _preferences.Normalize();
    }

    // ====================================================================
    // CURRENT PREFERENCES
    // ====================================================================

    /// <summary>
    /// التفضيلات الحالية.
    ///
    /// ملاحظة:
    /// يتم إرجاع نفس الكائن الداخلي للحفاظ على توافق الخدمة
    /// مع بقية طبقات التطبيق الحالية.
    /// </summary>
    public UsrPref Preferences
    {
        get
        {
            lock (_sync)
            {
                return _preferences;
            }
        }
    }

    // ====================================================================
    // LOAD
    // ====================================================================

    /// <summary>
    /// تحميل التفضيلات من التخزين المحلي.
    /// </summary>
    public UsrPref Load()
    {
        lock (_sync)
        {
            _preferences = UsrPref.Load();

            _preferences.Normalize();

            return _preferences;
        }
    }

    // ====================================================================
    // SAVE
    // ====================================================================

    /// <summary>
    /// حفظ التفضيلات الحالية إلى القرص.
    /// </summary>
    public void Save()
    {
        lock (_sync)
        {
            _preferences.Normalize();
            _preferences.Save();
        }
    }

    // ====================================================================
    // WINDOW
    // ====================================================================

    /// <summary>
    /// تطبيق تفضيلات النافذة الحالية.
    /// </summary>
    public void ApplyToWindow(Window? window)
    {
        if (window is null)
            return;

        lock (_sync)
        {
            _preferences.ApplyToWindow(window);
        }
    }

    /// <summary>
    /// التقاط حالة النافذة الحالية.
    /// </summary>
    public void SaveFromWindow(Window? window)
    {
        if (window is null)
            return;

        lock (_sync)
        {
            _preferences.SaveFromWindow(window);
        }
    }

    // ====================================================================
    // LANGUAGE
    // ====================================================================

    /// <summary>
    /// تغيير لغة المستخدم.
    ///
    /// القيم غير المعروفة يتم تطبيعها بواسطة UsrPref.Normalize().
    /// </summary>
    public void SetLanguage(string? language)
    {
        lock (_sync)
        {
            _preferences.Lang =
                string.IsNullOrWhiteSpace(language)
                    ? LangDirSv.DefaultLanguageCode
                    : language.Trim();

            _preferences.LangSet = true;

            _preferences.Normalize();
        }
    }

    /// <summary>
    /// تغيير اللغة وتطبيقها مباشرة على النافذة.
    /// </summary>
    public void SetLanguage(
        string? language,
        Window? window)
    {
        lock (_sync)
        {
            _preferences.Lang =
                string.IsNullOrWhiteSpace(language)
                    ? LangDirSv.DefaultLanguageCode
                    : language.Trim();

            _preferences.LangSet = true;

            _preferences.Normalize();

            if (window is not null)
            {
                _preferences.ApplyToWindow(window);
            }
        }
    }

    // ====================================================================
    // THEME
    // ====================================================================

    /// <summary>
    /// تغيير الثيم.
    /// القيم المدعومة:
    /// Dark / Light
    /// </summary>
    public void SetTheme(string? theme)
    {
        lock (_sync)
        {
            _preferences.Theme =
                string.Equals(
                    theme?.Trim(),
                    "Light",
                    StringComparison.OrdinalIgnoreCase)
                    ? "Light"
                    : "Dark";

            _preferences.Normalize();
        }
    }

    // ====================================================================
    // CURRENCY
    // ====================================================================

    /// <summary>
    /// تغيير العملة الافتراضية.
    /// </summary>
    public void SetCurrency(string? currencyCode)
    {
        lock (_sync)
        {
            if (!string.IsNullOrWhiteSpace(currencyCode))
            {
                _preferences.CurrencyCode =
                    currencyCode.Trim();
            }

            _preferences.Normalize();
        }
    }

    // ====================================================================
    // DATE FORMAT
    // ====================================================================

    /// <summary>
    /// تغيير تنسيق التاريخ.
    /// </summary>
    public void SetDateFormat(string? dateFormat)
    {
        lock (_sync)
        {
            if (!string.IsNullOrWhiteSpace(dateFormat))
            {
                _preferences.DateFormat =
                    dateFormat.Trim();
            }

            _preferences.Normalize();
        }
    }

    // ====================================================================
    // DECIMAL DIGITS
    // ====================================================================

    /// <summary>
    /// تغيير عدد المنازل العشرية.
    /// </summary>
    public void SetDecimalDigits(int digits)
    {
        lock (_sync)
        {
            _preferences.DecimalDigits =
                Math.Clamp(digits, 0, 4);
        }
    }

    // ====================================================================
    // COMPACT MODE
    // ====================================================================

    /// <summary>
    /// تفعيل أو تعطيل الوضع المضغوط.
    /// </summary>
    public void SetCompactMode(bool enabled)
    {
        lock (_sync)
        {
            _preferences.CompactMode = enabled;
        }
    }

    // ====================================================================
    // RESET
    // ====================================================================

    /// <summary>
    /// إعادة جميع التفضيلات إلى الإعدادات الافتراضية.
    /// </summary>
    public void Reset()
    {
        lock (_sync)
        {
            _preferences = new UsrPref();

            _preferences.Normalize();
        }
    }

    // ====================================================================
    // RESET + SAVE
    // ====================================================================

    /// <summary>
    /// إعادة التفضيلات إلى الوضع الافتراضي وحفظها.
    /// </summary>
    public void ResetAndSave()
    {
        lock (_sync)
        {
            _preferences = new UsrPref();

            _preferences.Normalize();

            _preferences.Save();
        }
    }
}