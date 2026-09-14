-- ═════════════════════════════════════════════════════════════════════════════════
-- FILE: dba/mig/003_nav_ribbon.sql
-- SYSTEM: ShouTech ERP Enterprise Core
-- MIGRATION: 003 — Main Menu + Ribbon Navigation Catalog
-- DESCRIPTION:
--   Deploys enterprise navigation schema and seeds all menu/ribbon entries
--   extracted from MainWindow.xaml (regenerate seed via tools/generate_nav_seed.ps1)
-- ═════════════════════════════════════════════════════════════════════════════════

SET NOCOUNT ON;
GO

PRINT 'Migration 003: Navigation schema + seed (menu + ribbon)...';
GO

:r "../sys/nav.sql"
GO

:r "../sds/sds_nav.sql"
GO

PRINT 'Migration 003 completed.';
GO
