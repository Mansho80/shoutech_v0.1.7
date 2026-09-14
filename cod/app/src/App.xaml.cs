// ========================================================================
// FILE: App.xaml.cs
// PROJECT: SHOUTECH ERP
// PURPOSE: Application Bootstrap / Startup / Localization / DI
// FRAMEWORK: .NET 8 / WPF
// ========================================================================

#nullable enable

using System;
using System.Windows;
using ShouTech.App.Common;
using System.Windows.Threading;
using Microsoft.Extensions.DependencyInjection;
using ShouTech.App.Configuration;
using ShouTech.App.Localization;
using ShouTech.App.Services;
using ShouTech.App.Views;

namespace ShouTech.App
{
    public partial class App : System.Windows.Application
    {
        // ====================================================================
        // DEPENDENCY INJECTION CONTAINER
        // ====================================================================

        private IServiceProvider? _serviceProvider;

        // ====================================================================
        // GLOBAL LOCALIZATION SERVICE
        // ====================================================================

        public ILocSvc Localization { get; } = new LocSvc();

        // ====================================================================
        // CURRENT LANGUAGE
        // Single source used by the application UI.
        //
        // Supported language codes:
        // ar = Arabic
        // en = English
        // fr = French
        // ku = Kurdish
        // tr = Turkish
        // ====================================================================

        public static string CurrentLanguageCode { get; private set; } = "en";

        // ====================================================================
        // APPLICATION LANGUAGE
        // ====================================================================

        public static void SetApplicationLanguage(string? langCode)
        {
            // ------------------------------------------------------------
            // 1. Normalize language code (ar / en / fr / tr only)
            // ------------------------------------------------------------

            langCode = NormalizeLanguageCode(langCode);
            CurrentLanguageCode = langCode;

            // ------------------------------------------------------------
            // 2. Culture + localization service (must not crash host)
            // ------------------------------------------------------------

            try
            {
                LangDirSv.ApplyCulture(langCode);
            }
            catch
            {
                // Non-fatal: keep previous culture.
            }

            try
            {
                if (Current is App app)
                    app.Localization.SetLanguage(langCode);
            }
            catch
            {
                // Non-fatal: keep previous strings.
            }

            // ------------------------------------------------------------
            // 3. Defer FlowDirection + UI string refresh to avoid WPF
            //    layout re-entrancy crashes (Ribbon + RTL/LTR switch).
            // ------------------------------------------------------------

            void ApplyUi()
            {
                try { LangDirSv.ApplyToAllWindows(langCode); } catch { }
                try { UiLoczr.ScheduleApplyToAllWindows(); } catch { }
                try { UiShellSync.OnLanguageChanged(langCode); } catch { }
            }

            try
            {
                if (Current?.Dispatcher != null)
                {
                    Current.Dispatcher.BeginInvoke(
                        System.Windows.Threading.DispatcherPriority.Background,
                        new System.Action(ApplyUi));
                }
                else
                {
                    ApplyUi();
                }
            }
            catch
            {
                ApplyUi();
            }
        }


        // ====================================================================
        // LANGUAGE NORMALIZATION
        // ====================================================================

        private static string NormalizeLanguageCode(string? langCode)
        {
            var code = (langCode ?? string.Empty)
                .Trim()
                .ToLowerInvariant();

            return code switch
            {
                "ar" or "ar-sa" or "ar-kw" or "ar-ae" or "ar-eg"
                    => "ar",

                "en" or "en-us" or "en-gb"
                    => "en",

                "fr" or "fr-fr"
                    => "fr",

                "ku" or "ku-tr"
                    => "ku",

                "tr" or "tr-tr"
                    => "tr",

                _ => "en"
            };
        }

        // ====================================================================
        // APPLICATION STARTUP
        // ====================================================================

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            try { UiShellSync.EnsureApplicationHooks(); } catch { }

            // ------------------------------------------------------------
            // 1. GLOBAL EXCEPTION HANDLERS
            // ------------------------------------------------------------

            AppDomain.CurrentDomain.UnhandledException +=
                CurrentDomain_UnhandledException;

            DispatcherUnhandledException +=
                Dispatcher_UnhandledException;

            // ------------------------------------------------------------
            // 2. CONFIGURE DEPENDENCY INJECTION
            // ------------------------------------------------------------

            var services = new ServiceCollection();

            ConfigureServices(services);

            _serviceProvider = services.BuildServiceProvider();

            // ------------------------------------------------------------
            // 3. INITIALIZE APPLICATION HOST
            // ------------------------------------------------------------

            AppHost.Initialize();

            // ------------------------------------------------------------
            // 4. START APPLICATION SEQUENCE
            // ------------------------------------------------------------

            RunStartupSequence();
        }

        // ====================================================================
        // DOMAIN / PROCESS UNHANDLED EXCEPTION
        // ====================================================================

        private static void CurrentDomain_UnhandledException(
            object sender,
            UnhandledExceptionEventArgs args)
        {
            try
            {
                if (args.ExceptionObject is Exception ex)
                {
                    MessageBox.Show(
                        ex.Message,
                        "Unexpected Error",
                        MessageBoxButton.OK,
                        MessageBoxImage.Error);
                }
            }
            catch
            {
                // Never throw from the global exception handler.
            }
        }

        // ====================================================================
        // WPF DISPATCHER EXCEPTION
        // ====================================================================

        private static void Dispatcher_UnhandledException(
            object sender,
            DispatcherUnhandledExceptionEventArgs args)
        {
            try
            {
                MessageBox.Show(
                    args.Exception.Message,
                    "Application Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }
            catch
            {
                // Never throw from the global exception handler.
            }

            // Prevent immediate application termination for UI exceptions.
            args.Handled = true;
        }

        // ====================================================================
        // DEPENDENCY INJECTION REGISTRATION
        // ====================================================================

        private static void ConfigureServices(
            IServiceCollection services)
        {
            // ------------------------------------------------------------
            // COMPANY SERVICES
            // ------------------------------------------------------------

            services.AddSingleton<ICompanyRegistryService, CoRegSvc>();
            services.AddSingleton<ICoRegSvc, CoRegSvc>();

            // ------------------------------------------------------------
            // WINDOWS
            // ------------------------------------------------------------

            services.AddTransient<Lang>();
            services.AddTransient<SplWin>();
            services.AddTransient<ComWin>();
            services.AddTransient<LogWin>();
            services.AddTransient<MWin>();
        }

        // ====================================================================
        // STARTUP SEQUENCE
        // ====================================================================

        private void RunStartupSequence()
        {
            // ------------------------------------------------------------
            // CRITICAL: Prevent auto-shutdown when the language dialog
            // is the only open window and closes (WPF default is
            // OnLastWindowClose which kills the process before splash).
            // ------------------------------------------------------------
            ShutdownMode = ShutdownMode.OnExplicitShutdown;

            // ------------------------------------------------------------
            // 1. LOAD + NORMALIZE USER PREFERENCES
            // ------------------------------------------------------------
            UsrPref pref;
            try
            {
                pref = UsrPref.Load();
                pref.Normalize();
            }
            catch
            {
                pref = new UsrPref();
            }

            // ------------------------------------------------------------
            // 2. FIRST-RUN LANGUAGE SELECTION
            // ------------------------------------------------------------
            if (!pref.LangSet)
            {
                bool accepted = false;
                string chosen = "en";

                try
                {
                    var langWin = _serviceProvider?.GetService<Lang>() ?? new Lang();
                    accepted = langWin.ShowDialog() == true;
                    if (accepted)
                        chosen = NormalizeLanguageCode(langWin.Selected);
                }
                catch (Exception)
                {
                    accepted = false;
                }

                if (!accepted)
                {
                    try { Shutdown(); } catch { }
                    return;
                }

                if (chosen is not ("ar" or "en" or "fr" or "tr"))
                    chosen = "en";

                pref.Lang = chosen;
                pref.LangSet = true;
                try { pref.Save(); } catch { }
            }
            else
            {
                pref.Lang = NormalizeLanguageCode(pref.Lang);
                if (pref.Lang is not ("ar" or "en" or "fr" or "tr"))
                    pref.Lang = "en";
                try { pref.Save(); } catch { }
            }

            // ------------------------------------------------------------
            // 3. APPLY LANGUAGE (after dialog fully closed)
            // ------------------------------------------------------------
            try
            {
                SetApplicationLanguage(pref.Lang);
            }
            catch
            {
                try { SetApplicationLanguage("en"); } catch { }
                pref.Lang = "en";
                try { pref.Save(); } catch { }
            }

            // ------------------------------------------------------------
            // 4. SHOW SPLASH SCREEN — always continue the pipeline
            // ------------------------------------------------------------
            try
            {
                ShowSplashScreen();
            }
            catch (Exception ex)
            {
                try
                {
                    MessageBox.Show(
                        "Startup error: " + ex.Message,
                        "ShouTech ERP",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning);
                }
                catch { }

                try { ShowCompanySelection(); }
                catch
                {
                    try { ShowLogin(); } catch { try { Shutdown(); } catch { } }
                }
            }
        }

        // ====================================================================
        // SPLASH SCREEN
        // ====================================================================

        public void ShowSplashScreen()
        {
            try
            {
                var splash = _serviceProvider?.GetService<SplWin>() ?? new SplWin();
                MainWindow = splash;
                splash.Show();
                splash.Activate();
            }
            catch (Exception ex)
            {
                // Last resort: skip splash and continue pipeline
                try
                {
                    MessageBox.Show(
                        "Splash failed: " + ex.Message,
                        "ShouTech ERP",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning);
                }
                catch { }

                ShowCompanySelection();
            }
        }

        // ====================================================================
        // COMPANY SELECTION
        // ====================================================================

        public void ShowCompanySelection()
        {
            if (_serviceProvider is null)
                throw new InvalidOperationException("The dependency injection container has not been initialized.");

            var companyWindow =
                _serviceProvider.GetRequiredService<ComWin>();

            companyWindow.Show();
        }

        // ====================================================================
        // LOGIN
        // ====================================================================

        public void ShowLogin()
        {
            if (_serviceProvider is null)
                throw new InvalidOperationException("The dependency injection container has not been initialized.");

            var loginWindow =
                _serviceProvider.GetRequiredService<LogWin>();

            loginWindow.Show();
        }

        // ====================================================================
        // MAIN APPLICATION
        // ====================================================================

        public void ShowMainApp()
        {
            if (_serviceProvider is null)
                throw new InvalidOperationException("The dependency injection container has not been initialized.");

            var mainWindow =
                _serviceProvider.GetService<MWin>();

            if (mainWindow is null)
                return;

            MainWindow = mainWindow;

            mainWindow.Show();
        }

        // ====================================================================
        // APPLICATION EXIT
        // ====================================================================

        protected override void OnExit(ExitEventArgs e)
        {
            try
            {
                // ------------------------------------------------------------
                // Stop online coordinator
                // ------------------------------------------------------------

                AppHost.OnlineCoordinator?.StopCoordinator();

                // ------------------------------------------------------------
                // Dispose coordinator
                // ------------------------------------------------------------

                if (AppHost.OnlineCoordinator is IDisposable disposableCoordinator)
                {
                    disposableCoordinator.Dispose();
                }

                // ------------------------------------------------------------
                // Dispose DI container
                // ------------------------------------------------------------

                if (_serviceProvider is IDisposable disposableProvider)
                {
                    disposableProvider.Dispose();
                }
            }
            catch
            {
                // Shutdown must never be interrupted by cleanup errors.
            }

            base.OnExit(e);
        }
    }
}