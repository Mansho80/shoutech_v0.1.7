using System.Threading.Tasks;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using ShouTech.App.Common;
using ShouTech.App.Configuration;
using ShouTech.App.Localization;
using ShouTech.App.Services;
using ShouTech.App.Views;
using WpfApp = System.Windows.Application;

namespace ShouTech.App.ViewModels
{
    public partial class LogWinVM : ObservableObject
    {
        private readonly ILocSvc _localization;

        [ObservableProperty]
        [NotifyCanExecuteChangedFor(nameof(LoginCommand))]
        private bool _isLoading;

        [ObservableProperty]
        private string _statusMessage = string.Empty;

        [ObservableProperty]
        private bool _isStatusError;

        [ObservableProperty]
        private string? _companyName;

        [ObservableProperty]
        private string _windowTitle = string.Empty;

        [ObservableProperty]
        [NotifyCanExecuteChangedFor(nameof(LoginCommand))]
        private string _username = "admin";

        [ObservableProperty]
        private string _password = string.Empty;

        [ObservableProperty]
        private bool _isPasswordVisible;

        [ObservableProperty]
        private bool _hideUsernameField;

        [ObservableProperty]
        private bool _hideUsernameOnNextLaunch;

        [ObservableProperty]
        private string? _usernameError;

        [ObservableProperty]
        private string? _passwordError;

        [ObservableProperty]
        private string _usernameLabel = string.Empty;

        [ObservableProperty]
        private string _passwordLabel = string.Empty;

        [ObservableProperty]
        private string _hideUsernameOptionLabel = string.Empty;

        [ObservableProperty]
        private string _signInLabel = string.Empty;

        [ObservableProperty]
        private string _cancelLabel = string.Empty;

        public event Action? LoginSucceeded;
        public event Action? RequestClose;
        public event Action? RequestFocusUsername;
        public event Action? RequestFocusPassword;

        public LogWinVM()
        {
            _localization = AppHost.Localization;
            _localization.LanguageChanged += OnLanguageChanged;
            RefreshLocalizedStrings();
        }

        public void InitializeFromSelectedCompany()
        {
            if (WpfApp.Current.Properties["SelectedCompany"] is CompanyItem company)
            {
                var displayName = company.GetDisplayName(ShouTech.App.App.CurrentLanguageCode);
                CompanyName = displayName;
                WindowTitle = AppFormat.Format(Loc.Get("Login.WindowTitleWithCompany"), displayName);
            }

            var prefs = AppPrefsSvc.Load();
            HideUsernameField = prefs.HideUsernameOnNextLaunch;
            HideUsernameOnNextLaunch = prefs.HideUsernameOnNextLaunch;

            if (!string.IsNullOrWhiteSpace(prefs.RememberedUsername))
                Username = prefs.RememberedUsername.Trim();
        }

        partial void OnHideUsernameFieldChanged(bool value)
        {
            OnPropertyChanged(nameof(UsernameSectionVisibility));
        }

        public Visibility UsernameSectionVisibility =>
            HideUsernameField ? Visibility.Collapsed : Visibility.Visible;

        partial void OnIsPasswordVisibleChanged(bool value)
        {
            OnPropertyChanged(nameof(PasswordFieldVisibility));
            OnPropertyChanged(nameof(PasswordTextVisibility));
        }

        public Visibility PasswordFieldVisibility =>
            IsPasswordVisible ? Visibility.Collapsed : Visibility.Visible;

        public Visibility PasswordTextVisibility =>
            IsPasswordVisible ? Visibility.Visible : Visibility.Collapsed;

        [RelayCommand(CanExecute = nameof(CanLogin))]
        private async Task LoginAsync()
        {
            if (!ValidateInputs())
                return;

            IsLoading = true;
            IsStatusError = false;
            StatusMessage = Loc.Get("Login.Verifying");
            ClearFieldErrors();

            var pass = Password;

            try
            {
                await Task.Delay(600);

                var user = HideUsernameField ? string.Empty : Username.Trim();
                var result = await AppHost.Auth.LoginAsync(user, pass);
                if (result.Success && result.User != null)
                {
                    StatusMessage = Loc.Get("Login.Success");
                    IsStatusError = false;

                    var appPrefs = AppPrefsSvc.Load();
                    appPrefs.RememberedUsername = Username.Trim();
                    appPrefs.HideUsernameOnNextLaunch = HideUsernameOnNextLaunch;
                    AppPrefsSvc.Save(appPrefs);

                    await Task.Delay(300);
                    LoginSucceeded?.Invoke();
                }
                else
                {
                    StatusMessage = Loc.Get("Login.InvalidCredentials");
                    IsStatusError = true;
                    Password = string.Empty;
                    RequestFocusPassword?.Invoke();
                }
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private void Cancel() => RequestClose?.Invoke();

        private bool CanLogin() => !IsLoading;

        private bool ValidateInputs()
        {
            ClearFieldErrors();
            IsStatusError = false;
            StatusMessage = Loc.Get("Login.DefaultStatus");

            var isValid = true;

            if (!HideUsernameField && string.IsNullOrWhiteSpace(Username))
            {
                UsernameError = Loc.Get("Login.UsernameRequired");
                isValid = false;
            }

            if (string.IsNullOrEmpty(Password))
            {
                PasswordError = Loc.Get("Login.PasswordRequired");
                isValid = false;
            }

            if (!isValid)
            {
                StatusMessage = Loc.Get("Login.FixFields");
                IsStatusError = true;

                if (!string.IsNullOrWhiteSpace(UsernameError))
                    RequestFocusUsername?.Invoke();
                else if (!string.IsNullOrWhiteSpace(PasswordError))
                    RequestFocusPassword?.Invoke();
            }

            return isValid;
        }

        private void ClearFieldErrors()
        {
            UsernameError = null;
            PasswordError = null;
        }

        private void OnLanguageChanged(object? sender, EventArgs e) => RefreshLocalizedStrings();

        private void RefreshLocalizedStrings()
        {
            SignInLabel = Loc.Get("Login.SignIn");
            CancelLabel = Loc.Get("Login.Cancel");
            UsernameLabel = Loc.Get("Login.Username");
            PasswordLabel = Loc.Get("Login.Password");
            HideUsernameOptionLabel = Loc.Get("Login.HideUsernameNextTime");
            StatusMessage = Loc.Get("Login.DefaultStatus");
            // Re-resolve company display name for the active language (AR vs EN/FR/TR).
            if (WpfApp.Current?.Properties["SelectedCompany"] is CompanyItem selected)
            {
                CompanyName = selected.GetDisplayName(ShouTech.App.App.CurrentLanguageCode);
            }

            WindowTitle = string.IsNullOrWhiteSpace(CompanyName)
                ? Loc.Get("Login.WindowTitle")
                : AppFormat.Format(Loc.Get("Login.WindowTitleWithCompany"), CompanyName);
        }
    }
}
