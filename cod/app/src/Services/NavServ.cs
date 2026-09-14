using System;
using System.Collections.Concurrent;
using System.Threading.Tasks;
using ShouTech.App.Navigation;
using ShouTech.App.ViewModels;
using ShouTech.App.Views.Modules;

namespace ShouTech.App.Services
{
    /// <summary>
    /// Central navigation service — resolves ribbon actions to module workspace views.
    /// </summary>
    public sealed class NavServ : INavServ
    {
        private readonly ILogServ _logging;
        private readonly ConcurrentDictionary<string, object> _cache = new();

        public NavServ(ILogServ logging)
        {
            _logging = logging;
        }

        public object NavigateTo(string pageKey)
        {
            if (string.Equals(pageKey, "dashboard", StringComparison.OrdinalIgnoreCase))
                return GetOrCreate("dashboard", () => new DashVw());

            return GetOrCreate(pageKey, () => CreateWorkspace(pageKey, "General", pageKey));
        }

        public Task<object> NavigateToAsync(string pageKey) =>
            Task.FromResult(NavigateTo(pageKey));

        public object NavigateToModule(string actionTitle, string moduleKey, string? tabName = null, string? tabHeader = null)
        {
            var module = string.IsNullOrWhiteSpace(moduleKey)
                ? RibModMap.ResolveModule(tabName, tabHeader)
                : moduleKey;

            var cacheKey = $"{module}::{actionTitle}";
            return GetOrCreate(cacheKey, () => CreateWorkspace(actionTitle, module, actionTitle));
        }

        public void ClearCache() => _cache.Clear();

        private object GetOrCreate(string key, Func<object> factory)
        {
            return _cache.GetOrAdd(key, _ =>
            {
                _logging.LogInfo("Navigation", $"Opened: {key}");
                return factory();
            });
        }

        private static ModuleWorkspaceView CreateWorkspace(string title, string moduleKey, string actionTitle)
        {
            var vm = new ModWsVM(title, moduleKey, actionTitle);
            return new ModuleWorkspaceView { DataContext = vm };
        }
    }
}
