using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;

namespace ShouTech.App.ViewModels
{
    public sealed class DockedWinItem : INotifyPropertyChanged
    {
        public required string Title { get; init; }
        public required Window Window { get; init; }

        private double _left;
        private double _itemWidth;
        private int _zIndex;

        public double Left
        {
            get => _left;
            set { if (Set(ref _left, value)) OnPropertyChanged(); }
        }

        public double ItemWidth
        {
            get => _itemWidth;
            set { if (Set(ref _itemWidth, value)) OnPropertyChanged(); }
        }

        public int ZIndex
        {
            get => _zIndex;
            set { if (Set(ref _zIndex, value)) OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        private bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
        {
            if (Equals(field, value))
                return false;
            field = value;
            OnPropertyChanged(name);
            return true;
        }

        private void OnPropertyChanged([CallerMemberName] string? name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
