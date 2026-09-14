using ShouTech.App.Navigation;
using ShouTech.App.Interaction;
using CommunityToolkit.Mvvm.Input;

namespace ShouTech.App.ViewModels
{
    public class ModWsVM : BaseVM
    {
        private readonly IReadOnlyList<EntityContextAction> _itemActions;
        private readonly IReadOnlyList<EntityContextAction> _accountActions;

        public ModWsVM(string title, string moduleKey, string actionTitle)
        {
            Title = title;
            ModuleKey = moduleKey;
            ActionTitle = actionTitle;
            ModuleDisplayName = RibModMap.GetModuleDisplayName(moduleKey);
            Description = $"وحدة {ModuleDisplayName} — {ActionTitle}";
            StatusHint = "جاهز للتطوير — سيتم ربط هذه الشاشة بقاعدة البيانات والخدمات التجارية.";
            _itemActions = EntityContextActions.For(EntityContextType.Item);
            _accountActions = EntityContextActions.For(EntityContextType.Account);
            OpenContextActionCommand = new RelayCommand<EntityContextAction>(OpenContextAction);
        }

        public string Title { get; }
        public string ModuleKey { get; }
        public string ActionTitle { get; }
        public string ModuleDisplayName { get; }
        public string Description { get; }
        public string StatusHint { get; private set; }

        public RelayCommand<EntityContextAction> OpenContextActionCommand { get; }

        public IReadOnlyList<EntityContextAction> ItemActions => _itemActions;

        public IReadOnlyList<EntityContextAction> AccountActions => _accountActions;

        private void OpenContextAction(EntityContextAction? action)
        {
            if (action == null)
                return;

            StatusHint = $"تم طلب: {action.Label}";
            OnPropertyChanged(nameof(StatusHint));
        }
    }
}
