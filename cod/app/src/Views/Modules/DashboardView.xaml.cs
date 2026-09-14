using System.Globalization;
using System.Windows.Controls;
using ShouTech.App.Services;

namespace ShouTech.App.Views.Modules
{
    public partial class DashboardView : UserControl
    {
        public DashboardView()
        {
            InitializeComponent();
            Loaded += OnLoaded;
        }

        private async void OnLoaded(object sender, System.Windows.RoutedEventArgs e)
        {
            try
            {
                var data = AppServiceHost.Data;
                CustomersCount.Text = (await data.GetTotalCustomersAsync()).ToString("N0", CultureInfo.CurrentCulture);
                ProductsCount.Text = (await data.GetTotalProductsAsync()).ToString("N0", CultureInfo.CurrentCulture);
                PendingCount.Text = (await data.GetTotalPendingApprovalsAsync()).ToString("N0", CultureInfo.CurrentCulture);
            }
            catch
            {
                CustomersCount.Text = "—";
                ProductsCount.Text = "—";
                PendingCount.Text = "—";
            }
        }
    }
}
