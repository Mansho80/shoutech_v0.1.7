import os
from pathlib import Path

# =====================================================
# 1. تحديد المسار الجذر (عدّل هذا المسار حسب مشروعك)
# =====================================================
ROOT_DIR = Path("./cod/app/src/Views/Ribbon")

# =====================================================
# 2. تعريف هيكل المجلدات والملفات
# =====================================================
STRUCTURE = {
    # مجلدات المستوى الأول
    "dirs": [
        "RibbonTabs",
        "RibbonGroups",
        "ViewModels",
        "Controls",
    ],
    
    # الملفات في الجذر مباشرة
    "root_files": [
        "RibbonMain.xaml",
    ],
    
    # ملفات التبويبات (RibbonTabs)
    "tab_files": [
        "FileTab.xaml",
        "HomeTab.xaml",
        "InventoryTab.xaml",
        "AccountingTab.xaml",
        "POSTab.xaml",
        "InvoicesTab.xaml",
        "OrdersTab.xaml",
        "CustomersTab.xaml",
        "SalesmenTab.xaml",
        "ManufacturingTab.xaml",
        "BanksTab.xaml",
        "HRTab.xaml",
        "ReportsTab.xaml",
        "ToolsTab.xaml",
        "HelpTab.xaml",
    ],
    
    # ملفات المجموعات (RibbonGroups) - مقسمة إلى مجلدات فرعية
    "group_files": {
        "": [  # الملفات في جذر RibbonGroups مباشرة
            "FileOperationsGroup.xaml",
            "ImportExportGroup.xaml",
        ],
        "Inventory": [
            "InventoryMasterGroup.xaml",
            "InventoryTransactionsGroup.xaml",
            "InventoryReportsGroup.xaml",
        ],
        "Accounting": [
            "AccountingSetupGroup.xaml",
            "AccountingJournalsGroup.xaml",
            "AccountingReportsGroup.xaml",
        ],
        "POS": [
            "POSSessionGroup.xaml",
            "POSReportsGroup.xaml",
        ],
        "Shared": [
            "SearchBoxGroup.xaml",
            "QuickReportGallery.xaml",
            "CurrencyConverterGroup.xaml",
        ],
    },
    
    # ملفات ViewModels
    "viewmodel_files": [
        "RibbonTabViewModel.cs",
        "MainRibbonViewModel.cs",
    ],
    
    # ملفات Controls
    "control_files": [
        "ModernButton.xaml",
    ],
}

# =====================================================
# 3. محتويات القوالب (Templates) لملفات XAML / CS
# =====================================================

TEMPLATE_RIBONTAB = '''<fluent:RibbonTab x:Class="ShouTech.App.Views.Ribbon.RibbonTabs.{filename_without_ext}"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:fluent="clr-namespace:Fluent;assembly=Fluent.Ribbon"
                      xmlns:views="clr-namespace:ShouTech.App.Views.Ribbon.RibbonGroups"
                      Header="{DynamicResource str{tab_name}}" KeyTip="{tab_keytip}">
    
    <!--
        *************************************************************
        تبويب: {tab_name_display}
        *************************************************************
        هنا ستضيف مجموعاتك (RibbonGroups) بالشكل التالي:
        <views:InventoryMasterGroup />
        <views:InventoryTransactionsGroup />
        <views:InventoryReportsGroup />
    -->
    
    <!-- مجموعة افتراضية توضيحية (يمكنك حذفها) -->
    <fluent:RibbonGroup Header="مجموعة تجريبية">
        <fluent:Button Header="زر تجريبي" Command="{{Binding GenericCommand}}" CommandParameter="{tab_name}" />
    </fluent:RibbonGroup>
    
</fluent:RibbonTab>
'''

TEMPLATE_USERCONTROL_GROUP = '''<UserControl x:Class="ShouTech.App.Views.Ribbon.RibbonGroups.{subfolder}.{filename_without_ext}"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:fluent="clr-namespace:Fluent;assembly=Fluent.Ribbon">
    
    <!--
        *************************************************************
        مجموعة: {filename_without_ext}
        *************************************************************
        ضع هنا عناصر الـ RibbonGroup الخاصة بك
    -->
    
    <fluent:RibbonGroup Header="{DynamicResource strGroup{filename_without_ext}}}">
        <fluent:Button Header="أمر 1" Command="{{Binding GenericCommand}}" CommandParameter="Cmd1" />
        <fluent:Button Header="أمر 2" Command="{{Binding GenericCommand}}" CommandParameter="Cmd2" />
    </fluent:RibbonGroup>
    
</UserControl>
'''

TEMPLATE_RIBONMAIN = '''<fluent:Ribbon x:Class="ShouTech.App.Views.Ribbon.RibbonMain"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                      xmlns:fluent="clr-namespace:Fluent;assembly=Fluent.Ribbon"
                      xmlns:views="clr-namespace:ShouTech.App.Views.Ribbon.RibbonTabs">
    
    <!-- ================================================ -->
    <!-- شريط الوصول السريع (Quick Access Toolbar)        -->
    <!-- ================================================ -->
    <fluent:Ribbon.QuickAccessItems>
        <fluent:QuickAccessMenuItem Header="حفظ" Icon="Save" Command="{{Binding SaveCommand}}" />
        <fluent:QuickAccessMenuItem Header="تراجع" Icon="Undo" Command="{{Binding UndoCommand}}" />
        <fluent:QuickAccessSeparator />
        <fluent:QuickAccessMenuItem Header="شاشة البيع" Icon="POS" Command="{{Binding OpenPOSScreenCommand}}" />
    </fluent:Ribbon.QuickAccessItems>

    <!-- ================================================ -->
    <!-- التبويبات (يتم إضافتها ديناميكياً حسب الصلاحيات) -->
    <!-- ================================================ -->
    
    <!-- تبويب رئيسية (Home) -->
    <views:HomeTab />
    
    <!-- تبويب ملف (File) -->
    <views:FileTab />
    
    <!-- تبويب المستودعات (Inventory) -->
    <views:InventoryTab />
    
    <!-- تبويب الحسابات (Accounting) -->
    <views:AccountingTab />
    
    <!-- تبويب نقاط البيع (POS) - الأهم حالياً -->
    <views:POSTab />
    
    <!-- تبويب فواتير (Invoices) -->
    <views:InvoicesTab />
    
    <!-- تبويب طلبيات (Orders) -->
    <views:OrdersTab />
    
    <!-- تبويب عملاء (Customers) -->
    <views:CustomersTab />
    
    <!-- تبويب مندوب (Salesmen) -->
    <views:SalesmenTab />
    
    <!-- تبويب تصنيع (Manufacturing) -->
    <views:ManufacturingTab />
    
    <!-- تبويب بنوك (Banks) -->
    <views:BanksTab />
    
    <!-- تبويب موارد بشرية (HR) -->
    <views:HRTab />
    
    <!-- تبويب تقارير (Reports) -->
    <views:ReportsTab />
    
    <!-- تبويب أدوات (Tools) -->
    <views:ToolsTab />
    
    <!-- تبويب مساعدة (Help) -->
    <views:HelpTab />

</fluent:Ribbon>
'''

TEMPLATE_VIEWMODEL_CS = '''using System;
using System.Collections.ObjectModel;
using System.Windows.Input;
using ShouTech.App.Models;
using ShouTech.App.Services;

namespace ShouTech.App.ViewModels
{
    public class {filename_without_ext} : BaseViewModel
    {
        private readonly IMenuBuilder _menuBuilder;
        private readonly IAuthorizationService _authService;

        public ObservableCollection<RibbonTabModel> DynamicTabs { get; set; }

        public ICommand GenericCommand {{ get; }}

        public {filename_without_ext}(IMenuBuilder menuBuilder, IAuthorizationService authService)
        {{
            _menuBuilder = menuBuilder;
            _authService = authService;
            DynamicTabs = new ObservableCollection<RibbonTabModel>();

            GenericCommand = new RelayCommand<string>(ExecuteGenericCommand);

            LoadTabsAsync("user123");
        }}

        private async void LoadTabsAsync(string userId)
        {{
            var tabs = await _menuBuilder.BuildMenuAsync(userId);
            DynamicTabs.Clear();
            foreach (var tab in tabs)
                DynamicTabs.Add(tab);
        }}

        private void ExecuteGenericCommand(string parameter)
        {{
            // افتح النافذة المناسبة حسب الـ parameter
            System.Windows.MessageBox.Show($"تنفيذ الأمر: {{parameter}}");
        }}
    }}
}}
'''

TEMPLATE_CONTROL_XAML = '''<UserControl x:Class="ShouTech.App.Views.Ribbon.Controls.{filename_without_ext}"
                      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    
    <!--
        *************************************************************
        تحكم مخصص: {filename_without_ext}
        *************************************************************
    -->
    
    <Grid>
        <TextBlock Text="هذا تحكم مخصص: {filename_without_ext}" FontSize="14" />
    </Grid>
    
</UserControl>
'''

# =====================================================
# 4. دوال مساعدة لإنشاء المحتوى
# =====================================================

def generate_tab_content(filename):
    """توليد محتوى ملف تبويب (RibbonTab)"""
    name = filename.replace(".xaml", "")
    display_name = name.replace("Tab", "")
    keytip = display_name[0].upper()
    return TEMPLATE_RIBONTAB.format(
        filename_without_ext=name,
        tab_name=display_name,
        tab_name_display=display_name,
        tab_keytip=keytip
    )

def generate_group_content(filename, subfolder=""):
    """توليد محتوى ملف مجموعة (RibbonGroup)"""
    name = filename.replace(".xaml", "")
    return TEMPLATE_USERCONTROL_GROUP.format(
        filename_without_ext=name,
        subfolder=subfolder
    )

def generate_viewmodel_content(filename):
    name = filename.replace(".cs", "")
    return TEMPLATE_VIEWMODEL_CS.format(filename_without_ext=name)

def generate_control_content(filename):
    name = filename.replace(".xaml", "")
    return TEMPLATE_CONTROL_XAML.format(filename_without_ext=name)

# =====================================================
# 5. المنطق الرئيسي لإنشاء الملفات والمجلدات
# =====================================================

def create_structure():
    print(f"🚀 بدء إنشاء هيكل شريط الأدوات في: {ROOT_DIR.absolute()}")
    
    # 5.1 إنشاء المجلدات الرئيسية
    for dir_name in STRUCTURE["dirs"]:
        dir_path = ROOT_DIR / dir_name
        dir_path.mkdir(parents=True, exist_ok=True)
        print(f"✅ إنشاء مجلد: {dir_path}")

    # 5.2 إنشاء ملفات الجذر (RibbonMain.xaml)
    for file_name in STRUCTURE["root_files"]:
        file_path = ROOT_DIR / file_name
        file_path.write_text(TEMPLATE_RIBONMAIN, encoding="utf-8")
        print(f"✅ إنشاء ملف: {file_path}")

    # 5.3 إنشاء ملفات التبويبات (RibbonTabs)
    tabs_dir = ROOT_DIR / "RibbonTabs"
    for file_name in STRUCTURE["tab_files"]:
        file_path = tabs_dir / file_name
        content = generate_tab_content(file_name)
        file_path.write_text(content, encoding="utf-8")
        print(f"✅ إنشاء تبويب: {file_path}")

    # 5.4 إنشاء ملفات المجموعات (RibbonGroups)
    groups_root = ROOT_DIR / "RibbonGroups"
    # 5.4.1 المجلدات الفرعية للمجموعات
    for subfolder in STRUCTURE["group_files"].keys():
        if subfolder:
            subfolder_path = groups_root / subfolder
            subfolder_path.mkdir(parents=True, exist_ok=True)
            print(f"✅ إنشاء مجلد مجموعات: {subfolder_path}")
    
    # 5.4.2 إنشاء ملفات المجموعات داخل المجلدات المناسبة
    for subfolder, files in STRUCTURE["group_files"].items():
        target_dir = groups_root if not subfolder else groups_root / subfolder
        for file_name in files:
            file_path = target_dir / file_name
            content = generate_group_content(file_name, subfolder)
            file_path.write_text(content, encoding="utf-8")
            print(f"✅ إنشاء مجموعة: {file_path}")

    # 5.5 إنشاء ملفات ViewModels
    vm_dir = ROOT_DIR / "ViewModels"
    for file_name in STRUCTURE["viewmodel_files"]:
        file_path = vm_dir / file_name
        content = generate_viewmodel_content(file_name)
        file_path.write_text(content, encoding="utf-8")
        print(f"✅ إنشاء ViewModel: {file_path}")

    # 5.6 إنشاء ملفات Controls
    controls_dir = ROOT_DIR / "Controls"
    for file_name in STRUCTURE["control_files"]:
        file_path = controls_dir / file_name
        content = generate_control_content(file_name)
        file_path.write_text(content, encoding="utf-8")
        print(f"✅ إنشاء Control: {file_path}")

    print("\n🎉 اكتمل إنشاء الهيكل بنجاح!")
    print(f"📍 المسار: {ROOT_DIR.absolute()}")

# =====================================================
# 6. تشغيل السكربت
# =====================================================
if __name__ == "__main__":
    try:
        create_structure()
    except Exception as e:
        print(f"❌ حدث خطأ: {e}")