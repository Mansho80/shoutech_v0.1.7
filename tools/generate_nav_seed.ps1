#Requires -Version 5.1
<#
.SYNOPSIS
    Generates enterprise-grade navigation seed SQL from MainWindow.xaml + Lang JSON files.

.DESCRIPTION
    Parses the WPF shell (menu bar + ribbon) and emits idempotent MERGE statements for:
      sys.MainMenuItems, sys.RibbonTabs, sys.RibbonGroups, sys.RibbonItems, sec.Permissions

    Output: dba/sds/sds_nav.sql
#>
[CmdletBinding()]
param(
    [string]$RootPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RootPath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $scriptDir) { $scriptDir = Get-Location | Select-Object -ExpandProperty Path }
    $RootPath = (Resolve-Path (Join-Path $scriptDir '..')).Path
}

function Get-FlatLangMap {
    param([psobject]$Node, [string]$Prefix = '')
    $map = @{}
    foreach ($prop in $Node.PSObject.Properties) {
        $key = if ($Prefix) { "$Prefix.$($prop.Name)" } else { $prop.Name }
        if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
            foreach ($pair in (Get-FlatLangMap -Node $prop.Value -Prefix $key).GetEnumerator()) {
                $map[$pair.Key] = $pair.Value
            }
        }
        else {
            $map[$key] = [string]$prop.Value
        }
    }
    return $map
}

function Build-ReverseArabicMap {
    param([hashtable]$ArMap)
    $reverse = @{}
    foreach ($entry in $ArMap.GetEnumerator()) {
        $label = $entry.Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($label) -and -not $reverse.ContainsKey($label)) {
            $reverse[$label] = $entry.Key
        }
    }
    return $reverse
}

function Resolve-LocalizationKey {
    param(
        [string]$ArabicLabel,
        [hashtable]$ReverseAr,
        [string]$FallbackPrefix
    )
    $trimmed = $ArabicLabel.Trim()
    if ($ReverseAr.ContainsKey($trimmed)) {
        return $ReverseAr[$trimmed]
    }
    $code = ($trimmed -replace '[^\p{L}\p{N}]', '').ToUpperInvariant()
    if ($code.Length -gt 40) { $code = $code.Substring(0, 40) }
    return "$FallbackPrefix.$code"
}

function Get-SafeCode {
    param([string]$Value, [int]$Max = 80)
    $code = ($Value -replace '[^A-Za-z0-9_]', '_').ToUpperInvariant()
    while ($code -match '__') { $code = $code -replace '__', '_' }
    $code = $code.Trim('_')
    if ($code.Length -gt $Max) { $code = $code.Substring(0, $Max) }
    return $code
}

function Escape-Sql {
    param([string]$Value)
    if ($null -eq $Value) { return "NULL" }
    return "N'" + ($Value -replace "'", "''") + "'"
}

function Escape-SqlAscii {
    param([string]$Value)
    if ($null -eq $Value) { return "NULL" }
    return "'" + ($Value -replace "'", "''") + "'"
}

$mainWindowPath = Join-Path $RootPath 'cod\app\src\Views\MainWindow.xaml'
$arPath = Join-Path $RootPath 'cod\app\src\Resources\Lang\Ar.json'
$enPath = Join-Path $RootPath 'cod\app\src\Resources\Lang\En.json'
$mapperPath = Join-Path $RootPath 'cod\app\src\Navigation\RibbonModuleMapper.cs'

if (-not $OutputPath) {
    $OutputPath = Join-Path $RootPath 'dba\sds\sds_nav.sql'
}

$xaml = Get-Content -Raw -Encoding UTF8 -Path $mainWindowPath
$arJson = Get-Content -Raw -Encoding UTF8 -Path $arPath | ConvertFrom-Json
$enJson = Get-Content -Raw -Encoding UTF8 -Path $enPath | ConvertFrom-Json

$arMap = Get-FlatLangMap -Node $arJson
$enMap = Get-FlatLangMap -Node $enJson
$reverseAr = Build-ReverseArabicMap -ArMap $arMap

# MenuItemCode -> TabCode from MainWindow.xaml.cs handlers
$menuToTab = [ordered]@{
    'Menu.File'           = 'TabFile'
    'Menu.Inventory'      = 'TabInventory'
    'Menu.Accounts'       = 'TabAccounts'
    'Menu.Bonds'          = 'TabBonds'
    'Menu.Invoices'       = 'TabInvoices'
    'Menu.POS'            = 'TabPOS'
    'Menu.Orders'         = 'TabOrders'
    'Menu.Customers'      = 'TabCustomers'
    'Menu.SalesRep'       = 'TabSalesRep'
    'Menu.Manufacturing'  = 'TabManufacturing'
    'Menu.Banks'          = 'TabBanks'
    'Menu.Reports'        = 'TabReports'
    'Menu.Tools'          = 'TabTools'
    'Menu.OtherTools'     = 'TabOtherTools'
    'Menu.View'           = 'TabView'
    'Menu.Exit'           = 'TabExit'
    'Menu.Help'           = 'TabHelp'
}

# Module codes from RibbonModuleMapper
$tabToModule = @{}
$mapperText = Get-Content -Raw -Encoding UTF8 -Path $mapperPath
[regex]::Matches($mapperText, '\["(?<tab>Tab\w+)"\]\s*=\s*"(?<mod>[^"]+)"') | ForEach-Object {
    $tabToModule[$_.Groups['tab'].Value] = $_.Groups['mod'].Value
}

# Menu icons from XAML
$menuIcons = @{}
[regex]::Matches($xaml, 'loc:LocalizationProperties\.Key="(?<key>Menu\.\w+)"\s+loc:LocalizationProperties\.Icon="(?<icon>[^"]+)"') | ForEach-Object {
    $menuIcons[$_.Groups['key'].Value] = $_.Groups['icon'].Value
}

$mainMenus = @()
$order = 10
foreach ($entry in $menuToTab.GetEnumerator()) {
    $locKey = $entry.Key
    $tabCode = $entry.Value
    $menuCode = Get-SafeCode -Value ($locKey -replace '^Menu\.', 'MMI_') -Max 50
    $mainMenus += [pscustomobject]@{
        MenuItemCode    = $menuCode
        TabCode         = $tabCode
        LocalizationKey = $locKey
        IconEmoji       = $menuIcons[$locKey]
        ModuleCode      = $tabToModule[$tabCode]
        DisplayOrder    = $order
    }
    $order += 10
}

# Parse ribbon structure
$ribbonTabs = @()
$ribbonGroups = @()
$ribbonItems = @()
$permissions = @{}

$tabPattern = '<ribbon:RibbonTab\s+x:Name="(?<name>Tab\w+)"\s+Header="(?<header>[^"]+)"'
$tabMatches = [regex]::Matches($xaml, $tabPattern)

foreach ($tabMatch in $tabMatches) {
    $tabName = $tabMatch.Groups['name'].Value
    $tabStart = $tabMatch.Index
    $nextTab = [regex]::Match($xaml.Substring($tabStart + 1), '<ribbon:RibbonTab\s+x:Name=')
    $tabLength = if ($nextTab.Success) { $nextTab.Index + 1 } else { $xaml.Length - $tabStart }
    $tabBlock = $xaml.Substring($tabStart, $tabLength)

    $header = $tabMatch.Groups['header'].Value
    if ($header -match '^([^\p{L}\s]{1,2})') { $headerIcon = $Matches[1] } else { $headerIcon = $null }
    $menuEntry = $mainMenus | Where-Object { $_.TabCode -eq $tabName } | Select-Object -First 1
    $tabLocKey = if ($menuEntry) { $menuEntry.LocalizationKey } else { "Menu.$($tabName -replace '^Tab','')" }

    $ribbonTabs += [pscustomobject]@{
        TabCode         = $tabName
        MenuItemCode    = $menuEntry.MenuItemCode
        LocalizationKey = $tabLocKey
        HeaderIcon      = $headerIcon
        ModuleCode      = $tabToModule[$tabName]
        DisplayOrder    = $menuEntry.DisplayOrder
    }

    $groupOrder = 10
    $groupPattern = '<ribbon:RibbonGroup\s+Header="(?<header>[^"]+)"(?:\s+Tag="(?<tag>[^"]+)")?'
    $groupMatches = [regex]::Matches($tabBlock, $groupPattern)
    foreach ($groupMatch in $groupMatches) {
        $groupHeaderAr = $groupMatch.Groups['header'].Value
        $groupTag = $groupMatch.Groups['tag'].Value
        if (-not $groupTag) {
            $groupTag = Resolve-LocalizationKey -ArabicLabel $groupHeaderAr -ReverseAr $reverseAr -FallbackPrefix 'RibbonGroups'
        }
        $groupCode = Get-SafeCode -Value "${tabName}_$($groupTag -replace '\.', '_')"
        $groupTitleEn = if ($enMap.ContainsKey($groupTag)) { $enMap[$groupTag] } else { $groupHeaderAr }

        $ribbonGroups += [pscustomobject]@{
            GroupCode       = $groupCode
            TabCode         = $tabName
            LocalizationKey = $groupTag
            TitleAR         = $groupHeaderAr
            TitleEN         = $groupTitleEn
            DisplayOrder    = $groupOrder
        }
        $groupOrder += 10

        # Buttons within group block (approximate - until next group or end tab)
        $groupStart = $groupMatch.Index
        $nextGroup = [regex]::Match($tabBlock.Substring($groupStart + 1), '<ribbon:RibbonGroup\s+Header=')
        $groupLen = if ($nextGroup.Success) { $nextGroup.Index + 1 } else { $tabBlock.Length - $groupStart }
        $groupBlock = $tabBlock.Substring($groupStart, $groupLen)

        $itemOrder = 10
        $btnPattern = '<ribbon:RibbonButton\s+Label="(?<label>[^"]+)"(?:\s+Tag="(?<tag>[^"]+)")?(?:\s+Click="(?<click>[^"]+)")?'
        [regex]::Matches($groupBlock, $btnPattern) | ForEach-Object {
            $labelAr = $_.Groups['label'].Value
            $actionKey = $_.Groups['tag'].Value
            $click = $_.Groups['click'].Value
            if (-not $actionKey) {
                $actionKey = Resolve-LocalizationKey -ArabicLabel $labelAr -ReverseAr $reverseAr -FallbackPrefix $groupTag
            }
            $handler = if ($click -like 'OnLanguage*') { $click } else { 'RibbonButton' }
            $itemCode = Get-SafeCode -Value "${groupCode}_$($actionKey -replace '\.', '_')"
            $titleEn = if ($enMap.ContainsKey($actionKey)) { $enMap[$actionKey] } else { $labelAr }
            $permCode = "PERM_NAV_" + (Get-SafeCode -Value $actionKey -Max 90)

            $ribbonItems += [pscustomobject]@{
                ItemCode        = $itemCode
                GroupCode       = $groupCode
                TabCode         = $tabName
                LocalizationKey = $actionKey
                ActionKey       = $actionKey
                TitleAR         = $labelAr
                TitleEN         = $titleEn
                HandlerType     = $handler
                DisplayOrder    = $itemOrder
                PermissionCode  = $permCode
                ModuleCode      = ($actionKey -split '\.')[0]
            }
            $permissions[$permCode] = [pscustomobject]@{
                PermissionCode   = $permCode
                ModuleName     = ($actionKey -split '\.')[0]
                PermissionNameAR = $labelAr
                PermissionNameEN = $titleEn
            }
            $itemOrder += 10
        }
    }
}

# Build SQL
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine(@"
-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/sds/sds_nav.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MODULE: Navigation Seed Data (Menu + Ribbon) — AUTO-GENERATED
-- GENERATOR: tools/generate_nav_seed.ps1
-- GENERATED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
-- STATS: $($mainMenus.Count) menus, $($ribbonTabs.Count) tabs, $($ribbonGroups.Count) groups, $($ribbonItems.Count) items
-- ═════════════════════════════════════════════════════════════════════════════════

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

RAISERROR(N'🌱 [SEED] Loading enterprise navigation catalog (sys.MainMenuItems / Ribbon*)...', 0, 1) WITH NOWAIT;

BEGIN TRANSACTION;
BEGIN TRY

"@)

# Permissions MERGE
[void]$sb.AppendLine("    -- Navigation permissions catalog")
[void]$sb.AppendLine("    MERGE INTO sec.Permissions AS Target")
[void]$sb.AppendLine("    USING (VALUES")

$permLines = @()
foreach ($perm in ($permissions.Values | Sort-Object PermissionCode)) {
    $permLines += "        ($([string]::Join(', ', @(
        (Escape-SqlAscii $perm.PermissionCode),
        (Escape-SqlAscii $perm.ModuleName),
        (Escape-Sql $perm.PermissionNameAR),
        (Escape-SqlAscii $perm.PermissionNameEN)
    ))))"
}
[void]$sb.AppendLine(($permLines -join ",`n"))
[void]$sb.AppendLine(@"
    ) AS Source (PermissionCode, ModuleName, PermissionNameAR, PermissionNameEN)
    ON Target.PermissionCode = Source.PermissionCode
    WHEN NOT MATCHED THEN
        INSERT (PermissionCode, ModuleName, PermissionNameAR, PermissionNameEN)
        VALUES (Source.PermissionCode, Source.ModuleName, Source.PermissionNameAR, Source.PermissionNameEN);

"@)

# Main menu MERGE
[void]$sb.AppendLine("    MERGE INTO sys.MainMenuItems AS Target")
[void]$sb.AppendLine("    USING (VALUES")
$menuLines = @()
foreach ($m in $mainMenus) {
    $menuLines += "        (1, 1, $(Escape-SqlAscii $m.MenuItemCode), $(Escape-SqlAscii $m.TabCode), $(Escape-SqlAscii $m.LocalizationKey), $(Escape-Sql $m.IconEmoji), $(Escape-SqlAscii $m.ModuleCode), $($m.DisplayOrder))"
}
[void]$sb.AppendLine(($menuLines -join ",`n"))
[void]$sb.AppendLine(@"
    ) AS Source (TenantID, CompanyID, MenuItemCode, TabCode, LocalizationKey, IconEmoji, ModuleCode, DisplayOrder)
    ON Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.MenuItemCode = Source.MenuItemCode
    WHEN MATCHED THEN UPDATE SET
        TabCode = Source.TabCode,
        LocalizationKey = Source.LocalizationKey,
        IconEmoji = Source.IconEmoji,
        ModuleCode = Source.ModuleCode,
        DisplayOrder = Source.DisplayOrder,
        IsActive = 1,
        IsDeleted = 0,
        UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, MenuItemCode, TabCode, LocalizationKey, IconEmoji, ModuleCode, DisplayOrder)
        VALUES (Source.TenantID, Source.CompanyID, Source.MenuItemCode, Source.TabCode, Source.LocalizationKey, Source.IconEmoji, Source.ModuleCode, Source.DisplayOrder);

"@)

# Ribbon tabs MERGE
[void]$sb.AppendLine("    MERGE INTO sys.RibbonTabs AS Target")
[void]$sb.AppendLine("    USING (VALUES")
$tabLines = @()
foreach ($t in $ribbonTabs) {
    $menuCodeSql = if ($t.MenuItemCode) { Escape-SqlAscii $t.MenuItemCode } else { 'NULL' }
    $tabLines += "        (1, 1, $(Escape-SqlAscii $t.TabCode), $menuCodeSql, $(Escape-SqlAscii $t.LocalizationKey), $(Escape-Sql $t.HeaderIcon), $(Escape-SqlAscii $t.ModuleCode), $($t.DisplayOrder))"
}
[void]$sb.AppendLine(($tabLines -join ",`n"))
[void]$sb.AppendLine(@"
    ) AS Source (TenantID, CompanyID, TabCode, MenuItemCode, LocalizationKey, HeaderIcon, ModuleCode, DisplayOrder)
    ON Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.TabCode = Source.TabCode
    WHEN MATCHED THEN UPDATE SET
        MenuItemCode = Source.MenuItemCode,
        LocalizationKey = Source.LocalizationKey,
        HeaderIcon = Source.HeaderIcon,
        ModuleCode = Source.ModuleCode,
        DisplayOrder = Source.DisplayOrder,
        IsActive = 1,
        IsDeleted = 0,
        UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, TabCode, MenuItemCode, LocalizationKey, HeaderIcon, ModuleCode, DisplayOrder)
        VALUES (Source.TenantID, Source.CompanyID, Source.TabCode, Source.MenuItemCode, Source.LocalizationKey, Source.HeaderIcon, Source.ModuleCode, Source.DisplayOrder);

"@)

# Groups - batch in chunks of 50 for readability
[void]$sb.AppendLine("    MERGE INTO sys.RibbonGroups AS Target")
[void]$sb.AppendLine("    USING (VALUES")
$groupLines = @()
foreach ($g in $ribbonGroups) {
    $loc = if ($g.LocalizationKey) { Escape-SqlAscii $g.LocalizationKey } else { 'NULL' }
    $groupLines += "        (1, 1, $(Escape-SqlAscii $g.GroupCode), $(Escape-SqlAscii $g.TabCode), $loc, $(Escape-Sql $g.TitleAR), $(Escape-SqlAscii $g.TitleEN), $($g.DisplayOrder))"
}
[void]$sb.AppendLine(($groupLines -join ",`n"))
[void]$sb.AppendLine(@"
    ) AS Source (TenantID, CompanyID, GroupCode, TabCode, LocalizationKey, TitleAR, TitleEN, DisplayOrder)
    ON Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.GroupCode = Source.GroupCode
    WHEN MATCHED THEN UPDATE SET
        TabCode = Source.TabCode,
        LocalizationKey = Source.LocalizationKey,
        TitleAR = Source.TitleAR,
        TitleEN = Source.TitleEN,
        DisplayOrder = Source.DisplayOrder,
        IsActive = 1,
        IsDeleted = 0,
        UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, GroupCode, TabCode, LocalizationKey, TitleAR, TitleEN, DisplayOrder)
        VALUES (Source.TenantID, Source.CompanyID, Source.GroupCode, Source.TabCode, Source.LocalizationKey, Source.TitleAR, Source.TitleEN, Source.DisplayOrder);

"@)

# Items - may be large; still one MERGE
[void]$sb.AppendLine("    MERGE INTO sys.RibbonItems AS Target")
[void]$sb.AppendLine("    USING (VALUES")
$itemLines = @()
foreach ($i in $ribbonItems) {
    $itemLines += "        (1, 1, $(Escape-SqlAscii $i.ItemCode), $(Escape-SqlAscii $i.GroupCode), $(Escape-SqlAscii $i.TabCode), $(Escape-SqlAscii $i.LocalizationKey), $(Escape-SqlAscii $i.ActionKey), $(Escape-Sql $i.TitleAR), $(Escape-SqlAscii $i.TitleEN), $(Escape-SqlAscii $i.HandlerType), $(Escape-SqlAscii $i.PermissionCode), $($i.DisplayOrder))"
}
[void]$sb.AppendLine(($itemLines -join ",`n"))
[void]$sb.AppendLine(@"
    ) AS Source (TenantID, CompanyID, ItemCode, GroupCode, TabCode, LocalizationKey, ActionKey, TitleAR, TitleEN, HandlerType, PermissionCode, DisplayOrder)
    ON Target.TenantID = Source.TenantID AND Target.CompanyID = Source.CompanyID AND Target.ItemCode = Source.ItemCode
    WHEN MATCHED THEN UPDATE SET
        GroupCode = Source.GroupCode,
        TabCode = Source.TabCode,
        LocalizationKey = Source.LocalizationKey,
        ActionKey = Source.ActionKey,
        TitleAR = Source.TitleAR,
        TitleEN = Source.TitleEN,
        HandlerType = Source.HandlerType,
        PermissionID = (SELECT PermissionID FROM sec.Permissions WHERE PermissionCode = Source.PermissionCode),
        DisplayOrder = Source.DisplayOrder,
        IsActive = 1,
        IsDeleted = 0,
        UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (TenantID, CompanyID, ItemCode, GroupCode, TabCode, LocalizationKey, ActionKey, TitleAR, TitleEN, HandlerType, PermissionID, DisplayOrder)
        VALUES (Source.TenantID, Source.CompanyID, Source.ItemCode, Source.GroupCode, Source.TabCode, Source.LocalizationKey, Source.ActionKey, Source.TitleAR, Source.TitleEN, Source.HandlerType,
                (SELECT PermissionID FROM sec.Permissions WHERE PermissionCode = Source.PermissionCode), Source.DisplayOrder);

    COMMIT TRANSACTION;
    RAISERROR(N'✅ [SUCCESS] Navigation seed completed.', 0, 1) WITH NOWAIT;
END TRY
BEGIN CATCH
    IF (XACT_STATE()) <> 0 ROLLBACK TRANSACTION;
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(N'❌ [FATAL ERROR] sds_nav.sql failed: %s', 16, 1, @ErrMsg);
END CATCH;
GO
"@)

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), $utf8)

Write-Host "Generated: $OutputPath"
Write-Host "Menus: $($mainMenus.Count) | Tabs: $($ribbonTabs.Count) | Groups: $($ribbonGroups.Count) | Items: $($ribbonItems.Count) | Permissions: $($permissions.Count)"
