// ========================================================================
// FILE: Configuration/UsrPref.cs
// PROJECT: SHOUTECH ERP V10
// PURPOSE: Enterprise User Preferences & Window Persistence
// FRAMEWORK: .NET 8 / C# 12 / WPF
// ========================================================================

#nullable enable

using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;
using ShouTech.App.Services;

namespace ShouTech.App.Configuration;

/// <summary>
/// Source-generated JSON serialization context.
/// Reflection-free and suitable for trimming/AOT scenarios.
/// </summary>
[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(UsrPref))]
public partial class UsrPrefJsonContext : JsonSerializerContext
{
}

/// <summary>
/// Enterprise user preferences and UI state.
///
/// Stores:
/// - Language
/// - Theme
/// - Window dimensions
/// - Window position
/// - Window state
/// - Last selected tab
/// - Currency
/// - Date format
/// - Decimal precision
/// - Compact mode
/// </summary>
public sealed class UsrPref
{
    // ====================================================================
    // CONSTANTS
    // ====================================================================

    private const string ApplicationFolder = "ShouTech";
    private const string ProductFolder = "ERP";
    private const string PreferencesFileName = "userprefs.json";

    private const double MinWindowWidth = 800d;
    private const double MaxWindowWidth = 4000d;

    private const double MinWindowHeight = 600d;
    private const double MaxWindowHeight = 3000d;

    // ====================================================================
    // SYNCHRONIZATION
    // ====================================================================

    private static readonly object FileLock = new();

    // ====================================================================
    // FILE PATH
    // ====================================================================

    private static readonly string PreferencesDirectory =
        Path.Combine(
            Environment.GetFolderPath(
                Environment.SpecialFolder.LocalApplicationData),
            ApplicationFolder,
            ProductFolder);

    private static readonly string PreferencesPath =
        Path.Combine(
            PreferencesDirectory,
            PreferencesFileName);

    // ====================================================================
    // LANGUAGE
    // ====================================================================

    /// <summary>
    /// Preferred application language.
    /// </summary>
    public string Lang { get; set; } =
        LangDirSv.DefaultLanguageCode;

    /// <summary>
    /// Indicates whether the user explicitly selected a language.
    /// </summary>
    public bool LangSet { get; set; }

    /// <summary>
    /// Indicates that the mandatory initial company and administrator wizard completed.
    /// </summary>
    public bool CompanySetupComplete { get; set; }

    // ====================================================================
    // APPEARANCE
    // ====================================================================

    /// <summary>
    /// Current UI theme.
    /// Supported values: Dark / Light.
    /// </summary>
    public string Theme { get; set; } = "Light";

    /// <summary>
    /// Enables compact UI mode.
    /// </summary>
    public bool CompactMode { get; set; }

    // ====================================================================
    // WINDOW
    // ====================================================================

    /// <summary>
    /// Saved window width.
    /// </summary>
    public double WinW { get; set; } = 1400d;

    /// <summary>
    /// Saved window height.
    /// </summary>
    public double WinH { get; set; } = 900d;

    /// <summary>
    /// Saved window left position.
    /// </summary>
    public double WinL { get; set; }

    /// <summary>
    /// Saved window top position.
    /// </summary>
    public double WinT { get; set; }

    /// <summary>
    /// Saved WPF window state.
    /// </summary>
    public WindowState WinState { get; set; } =
        WindowState.Maximized;

    // ====================================================================
    // NAVIGATION
    // ====================================================================

    /// <summary>
    /// Last selected application tab.
    /// </summary>
    public string LastTab { get; set; } = "File";

    // ====================================================================
    // REGIONAL SETTINGS
    // ====================================================================

    /// <summary>
    /// Preferred currency code.
    /// Example: SAR, KWD, USD.
    /// </summary>
    public string CurrencyCode { get; set; } = "SAR";

    /// <summary>
    /// Preferred date format.
    /// </summary>
    public string DateFormat { get; set; } = "dd/MM/yyyy";

    /// <summary>
    /// Number of decimal digits used by the UI.
    /// </summary>
    public int DecimalDigits { get; set; } = 2;

    // ====================================================================
    // NORMALIZATION
    // ====================================================================

    /// <summary>
    /// Normalizes and validates all persisted preferences.
    /// </summary>
    public void Normalize()
    {
        Lang = NormalizeLanguageCode(Lang);

        Theme =
            string.Equals(
                Theme?.Trim(),
                "Light",
                StringComparison.OrdinalIgnoreCase)
                ? "Light"
                : "Dark";

        LastTab =
            string.IsNullOrWhiteSpace(LastTab)
                ? "File"
                : LastTab.Trim();

        CurrencyCode =
            NormalizeCurrencyCode(CurrencyCode);

        DateFormat =
            DateFormat switch
            {
                "dd/MM/yyyy" => "dd/MM/yyyy",
                "MM/dd/yyyy" => "MM/dd/yyyy",
                "yyyy-MM-dd" => "yyyy-MM-dd",
                _ => "dd/MM/yyyy"
            };

        DecimalDigits =
            Math.Clamp(DecimalDigits, 0, 4);

        WinW =
            SanitizeDimension(
                WinW,
                MinWindowWidth,
                MaxWindowWidth,
                1400d);

        WinH =
            SanitizeDimension(
                WinH,
                MinWindowHeight,
                MaxWindowHeight,
                900d);

        if (!double.IsFinite(WinL))
            WinL = 0d;

        if (!double.IsFinite(WinT))
            WinT = 0d;

        if (WinState is not
            WindowState.Normal and
            not WindowState.Minimized and
            not WindowState.Maximized)
        {
            WinState = WindowState.Maximized;
        }
    }

    // ====================================================================
    // LANGUAGE NORMALIZATION
    // ====================================================================

    private static string NormalizeLanguageCode(string? value)
    {
        var code =
            (value ?? string.Empty)
            .Trim()
            .ToLowerInvariant();

        return code switch
        {
            "ar" or "ar-sa" or "ar-ae" or "ar-kw"
                => "ar",

            "en" or "en-us" or "en-gb"
                => "en",

            _ => "en"
        };
    }

    // ====================================================================
    // CURRENCY NORMALIZATION
    // ====================================================================

    private static string NormalizeCurrencyCode(string? value)
    {
        var code =
            (value ?? string.Empty)
            .Trim()
            .ToUpperInvariant();

        if (string.IsNullOrWhiteSpace(code))
            return "SAR";

        if (code.Length > 3)
            code = code[..3];

        return code;
    }

    // ====================================================================
    // DIMENSION NORMALIZATION
    // ====================================================================

    private static double SanitizeDimension(
        double value,
        double minimum,
        double maximum,
        double fallback)
    {
        if (!double.IsFinite(value))
            return fallback;

        return Math.Clamp(
            value,
            minimum,
            maximum);
    }

    // ====================================================================
    // LOAD
    // ====================================================================

    /// <summary>
    /// Loads user preferences from local application storage.
    ///
    /// Corrupt or inaccessible preference files never prevent
    /// application startup. Defaults are returned instead.
    /// </summary>
    public static UsrPref Load()
    {
        lock (FileLock)
        {
            try
            {
                if (!File.Exists(PreferencesPath))
                    return new UsrPref();

                var json =
                    File.ReadAllText(PreferencesPath);

                if (string.IsNullOrWhiteSpace(json))
                    return new UsrPref();

                var preferences =
                    JsonSerializer.Deserialize(
                        json,
                        UsrPrefJsonContext.Default.UsrPref);

                if (preferences is null)
                    return new UsrPref();

                preferences.Normalize();

                return preferences;
            }
            catch (Exception ex) when (
                ex is IOException
                or UnauthorizedAccessException
                or JsonException
                or NotSupportedException)
            {
                return new UsrPref();
            }
        }
    }

    // ====================================================================
    // SAVE
    // ====================================================================

    /// <summary>
    /// Saves preferences using an atomic temporary-file replacement.
    /// </summary>
    public void Save()
    {
        lock (FileLock)
        {
            string? temporaryPath = null;

            try
            {
                Normalize();

                Directory.CreateDirectory(
                    PreferencesDirectory);

                var json =
                    JsonSerializer.Serialize(
                        this,
                        UsrPrefJsonContext.Default.UsrPref);

                temporaryPath =
                    PreferencesPath + ".tmp";

                File.WriteAllText(
                    temporaryPath,
                    json);

                File.Move(
                    temporaryPath,
                    PreferencesPath,
                    overwrite: true);

                temporaryPath = null;
            }
            catch (Exception ex) when (
                ex is IOException
                or UnauthorizedAccessException
                or JsonException
                or NotSupportedException)
            {
                // Preferences must never crash the application.
            }
            finally
            {
                if (temporaryPath is not null)
                {
                    try
                    {
                        if (File.Exists(temporaryPath))
                            File.Delete(temporaryPath);
                    }
                    catch
                    {
                        // Ignore cleanup failure.
                    }
                }
            }
        }
    }

    // ====================================================================
    // APPLY WINDOW
    // ====================================================================

    /// <summary>
    /// Applies persisted dimensions, position, state and language
    /// to a WPF window.
    /// </summary>
    public void ApplyToWindow(Window win)
    {
        if (win is null)
            return;

        Normalize();

        var workArea =
            SystemParameters.WorkArea;

        var maxWidth =
            Math.Max(
                MinWindowWidth,
                workArea.Width - 20d);

        var maxHeight =
            Math.Max(
                MinWindowHeight,
                workArea.Height - 20d);

        if (WinState != WindowState.Maximized)
        {
            win.Width =
                Math.Clamp(
                    WinW,
                    MinWindowWidth,
                    Math.Min(
                        MaxWindowWidth,
                        maxWidth));

            win.Height =
                Math.Clamp(
                    WinH,
                    MinWindowHeight,
                    Math.Min(
                        MaxWindowHeight,
                        maxHeight));

            if (IsPositionOnScreen(
                    WinL,
                    WinT,
                    win.Width,
                    win.Height))
            {
                win.WindowStartupLocation =
                    WindowStartupLocation.Manual;

                win.Left = WinL;
                win.Top = WinT;
            }
            else
            {
                win.WindowStartupLocation =
                    WindowStartupLocation.CenterScreen;
            }
        }

        win.WindowState =
            WinState == WindowState.Minimized
                ? WindowState.Normal
                : WinState;

        try
        {
            LangDirSv.ApplyToWindow(
                win,
                Lang);
        }
        catch
        {
            // Language application must never
            // prevent the window from opening.
        }
    }

    // ====================================================================
    // CAPTURE WINDOW
    // ====================================================================

    /// <summary>
    /// Captures the current WPF window dimensions,
    /// position and state.
    /// </summary>
    public void SaveFromWindow(Window win)
    {
        if (win is null)
            return;

        try
        {
            if (win.WindowState == WindowState.Normal)
            {
                WinW = win.Width;
                WinH = win.Height;
                WinL = win.Left;
                WinT = win.Top;
            }
            else if (win.RestoreBounds != Rect.Empty)
            {
                WinW = win.RestoreBounds.Width;
                WinH = win.RestoreBounds.Height;
                WinL = win.RestoreBounds.Left;
                WinT = win.RestoreBounds.Top;
            }

            WinState =
                win.WindowState == WindowState.Minimized
                    ? WindowState.Normal
                    : win.WindowState;

            Normalize();
        }
        catch
        {
            // Do not allow preference capture
            // to interfere with application shutdown.
        }
    }

    // ====================================================================
    // SCREEN VALIDATION
    // ====================================================================

    /// <summary>
    /// Determines whether the saved window rectangle
    /// is completely visible within the current virtual screen.
    /// </summary>
    private static bool IsPositionOnScreen(
        double left,
        double top,
        double width,
        double height)
    {
        if (!double.IsFinite(left) ||
            !double.IsFinite(top) ||
            !double.IsFinite(width) ||
            !double.IsFinite(height))
        {
            return false;
        }

        var virtualLeft =
            SystemParameters.VirtualScreenLeft;

        var virtualTop =
            SystemParameters.VirtualScreenTop;

        var virtualWidth =
            SystemParameters.VirtualScreenWidth;

        var virtualHeight =
            SystemParameters.VirtualScreenHeight;

        return
            left >= virtualLeft &&
            top >= virtualTop &&
            left + width <=
                virtualLeft + virtualWidth &&
            top + height <=
                virtualTop + virtualHeight;
    }
}