-- MySQL 8.0 core schema for companies, inventory and accounting journal.
CREATE TABLE IF NOT EXISTS companies (
    company_id CHAR(36) NOT NULL PRIMARY KEY,
    company_code VARCHAR(50) NOT NULL UNIQUE,
    company_name_ar VARCHAR(250) NOT NULL,
    company_name_en VARCHAR(250) NOT NULL,
    email VARCHAR(250), phone VARCHAR(50), mobile VARCHAR(50), address_line1 VARCHAR(500),
    commercial_registration VARCHAR(100), currency_code CHAR(3) NOT NULL DEFAULT 'USD',
    language_code VARCHAR(10) NOT NULL DEFAULT 'ar',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6)
);
CREATE TABLE IF NOT EXISTS users (
    user_id CHAR(36) NOT NULL PRIMARY KEY, company_id CHAR(36) NOT NULL,
    username VARCHAR(100) NOT NULL, password_hash VARCHAR(500) NOT NULL, password_salt VARCHAR(500) NOT NULL,
    full_name VARCHAR(200) NOT NULL, full_name_ar VARCHAR(200) NOT NULL, full_name_en VARCHAR(200) NOT NULL,
    email VARCHAR(250), must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    is_super_admin BOOLEAN NOT NULL DEFAULT FALSE, is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE, created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6),
    UNIQUE KEY uq_user_company_name (company_id, username),
    CONSTRAINT fk_user_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS fiscal_years (
    fiscal_year_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    company_id CHAR(36) NOT NULL, fiscal_year INT NOT NULL, database_name VARCHAR(200) NOT NULL,
    start_date DATE NOT NULL, end_date DATE NOT NULL, is_current BOOLEAN NOT NULL DEFAULT TRUE,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE KEY uq_fiscal_company_year (company_id, fiscal_year),
    CONSTRAINT fk_fiscal_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS roles (
    role_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id CHAR(36) NOT NULL,
    role_code VARCHAR(50) NOT NULL, role_name VARCHAR(150) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_role_company_code (company_id, role_code),
    CONSTRAINT fk_role_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS permissions (
    permission_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, permission_code VARCHAR(100) NOT NULL UNIQUE,
    permission_name VARCHAR(200) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS user_roles (
    user_id CHAR(36) NOT NULL, role_id INT NOT NULL, PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id), FOREIGN KEY (role_id) REFERENCES roles(role_id)
);
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id INT NOT NULL, permission_id INT NOT NULL, PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES roles(role_id), FOREIGN KEY (permission_id) REFERENCES permissions(permission_id)
);
CREATE TABLE IF NOT EXISTS units_of_measure (
    uom_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    company_id CHAR(36) NOT NULL,
    uom_code VARCHAR(30) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE KEY uq_uom_company_code (company_id, uom_code),
    CONSTRAINT fk_uom_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS products (
    product_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    company_id CHAR(36) NOT NULL,
    product_code VARCHAR(100) NOT NULL,
    product_name_ar VARCHAR(250) NOT NULL,
    product_name_en VARCHAR(250),
    category_id INT NOT NULL,
    primary_uom_id INT NOT NULL,
    default_sale_price DECIMAL(19,4) NOT NULL DEFAULT 0,
    default_purchase_price DECIMAL(19,4) NOT NULL DEFAULT 0,
    cost_price DECIMAL(19,4) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_by CHAR(36) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6),
    updated_by CHAR(36), updated_at DATETIME(6), deleted_by CHAR(36), deleted_at DATETIME(6),
    UNIQUE KEY uq_product_company_code (company_id, product_code),
    CONSTRAINT fk_product_company FOREIGN KEY (company_id) REFERENCES companies(company_id),
    CONSTRAINT fk_product_uom FOREIGN KEY (primary_uom_id) REFERENCES units_of_measure(uom_id)
);
CREATE TABLE IF NOT EXISTS journal_entries (
    journal_entry_id CHAR(36) NOT NULL PRIMARY KEY, company_id CHAR(36) NOT NULL,
    entry_date DATE NOT NULL, description VARCHAR(500) NOT NULL, status SMALLINT NOT NULL DEFAULT 0,
    created_by VARCHAR(100) NOT NULL, created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6),
    posted_by VARCHAR(100), posted_at DATETIME(6), reversed_by VARCHAR(100), reversed_at DATETIME(6),
    CONSTRAINT ck_journal_status CHECK (status IN (0,1,2)),
    CONSTRAINT fk_journal_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS journal_entry_lines (
    journal_entry_line_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, journal_entry_id CHAR(36) NOT NULL,
    line_number INT NOT NULL, account_id CHAR(36) NOT NULL, debit DECIMAL(19,4) NOT NULL DEFAULT 0,
    credit DECIMAL(19,4) NOT NULL DEFAULT 0, cost_center VARCHAR(100), note VARCHAR(500),
    UNIQUE KEY uq_journal_line (journal_entry_id,line_number),
    CONSTRAINT fk_line_entry FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(journal_entry_id),
    CONSTRAINT ck_line_amounts CHECK (debit >= 0 AND credit >= 0 AND ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)))
);
CREATE TABLE IF NOT EXISTS journal_audit_events (
    journal_audit_event_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, journal_entry_id CHAR(36) NOT NULL,
    event_type SMALLINT NOT NULL, actor VARCHAR(100) NOT NULL, event_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6),
    details VARCHAR(1000), CONSTRAINT fk_audit_entry FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(journal_entry_id)
);
CREATE TABLE IF NOT EXISTS stock_balances (
    stock_balance_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id CHAR(36) NOT NULL,
    warehouse_id BIGINT NOT NULL, product_id INT NOT NULL, available_qty DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_cost DECIMAL(18,6), last_updated DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE KEY uq_stock_balance (company_id,warehouse_id,product_id)
);
CREATE TABLE IF NOT EXISTS stock_movements (
    movement_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id CHAR(36) NOT NULL, movement_type VARCHAR(30) NOT NULL,
    movement_date DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), warehouse_id_to BIGINT, product_id INT NOT NULL,
    quantity DECIMAL(18,4) NOT NULL, unit_cost DECIMAL(18,6), reference_table VARCHAR(50), notes TEXT,
    created_by CHAR(36) NOT NULL, created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6)
);
