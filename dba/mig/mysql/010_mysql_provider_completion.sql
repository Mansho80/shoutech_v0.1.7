-- Completes the provider contract for installations that already applied 009.
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS email VARCHAR(250),
    ADD COLUMN IF NOT EXISTS phone VARCHAR(50),
    ADD COLUMN IF NOT EXISTS mobile VARCHAR(50),
    ADD COLUMN IF NOT EXISTS address_line1 VARCHAR(500),
    ADD COLUMN IF NOT EXISTS commercial_registration VARCHAR(100),
    ADD COLUMN IF NOT EXISTS currency_code CHAR(3) NOT NULL DEFAULT 'USD',
    ADD COLUMN IF NOT EXISTS language_code VARCHAR(10) NOT NULL DEFAULT 'ar';

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS password_salt VARCHAR(500) NOT NULL,
    ADD COLUMN IF NOT EXISTS full_name_ar VARCHAR(200) NOT NULL,
    ADD COLUMN IF NOT EXISTS full_name_en VARCHAR(200) NOT NULL,
    ADD COLUMN IF NOT EXISTS email VARCHAR(250),
    ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_super_admin BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE permissions
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS fiscal_years (
    fiscal_year_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    company_id CHAR(36) NOT NULL,
    fiscal_year INT NOT NULL,
    database_name VARCHAR(200) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE KEY uq_fiscal_company_year (company_id, fiscal_year),
    CONSTRAINT fk_fiscal_company FOREIGN KEY (company_id) REFERENCES companies(company_id)
);
