-- MySQL module schema. Tables are tenant-scoped and use CHAR(36) identifiers.
CREATE TABLE IF NOT EXISTS crm_business_partners (
    partner_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, partner_code VARCHAR(50) NOT NULL,
    partner_type VARCHAR(20) NOT NULL, name_ar VARCHAR(250) NOT NULL, name_en VARCHAR(250),
    tax_number VARCHAR(100), phone VARCHAR(50), email VARCHAR(250), is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), UNIQUE KEY uq_crm_partner(company_id,partner_code),
    FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS crm_sales_orders (
    order_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, partner_id CHAR(36),
    order_number VARCHAR(50) NOT NULL, order_date DATE NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    total_amount DECIMAL(19,4) NOT NULL DEFAULT 0, created_by CHAR(36) NOT NULL,
    UNIQUE KEY uq_crm_order(company_id,order_number), FOREIGN KEY(company_id) REFERENCES companies(company_id),
    FOREIGN KEY(partner_id) REFERENCES crm_business_partners(partner_id)
);
CREATE TABLE IF NOT EXISTS crm_sales_order_lines (
    line_id CHAR(36) PRIMARY KEY, order_id CHAR(36) NOT NULL, product_id INT NOT NULL,
    quantity DECIMAL(18,4) NOT NULL, unit_price DECIMAL(19,4) NOT NULL, tax_amount DECIMAL(19,4) NOT NULL DEFAULT 0,
    CHECK(quantity > 0 AND unit_price >= 0), FOREIGN KEY(order_id) REFERENCES crm_sales_orders(order_id)
);
CREATE TABLE IF NOT EXISTS hr_departments (
    department_id BIGINT AUTO_INCREMENT PRIMARY KEY, company_id CHAR(36) NOT NULL, code VARCHAR(50) NOT NULL,
    name_ar VARCHAR(150) NOT NULL, name_en VARCHAR(150), is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_hr_department(company_id,code), FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS hr_employees (
    employee_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, employee_code VARCHAR(50) NOT NULL,
    full_name_ar VARCHAR(200) NOT NULL, full_name_en VARCHAR(200), department_id BIGINT,
    hire_date DATE, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', UNIQUE KEY uq_hr_employee(company_id,employee_code),
    FOREIGN KEY(company_id) REFERENCES companies(company_id), FOREIGN KEY(department_id) REFERENCES hr_departments(department_id)
);
CREATE TABLE IF NOT EXISTS hr_leave_requests (
    leave_request_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, employee_id CHAR(36) NOT NULL,
    start_date DATE NOT NULL, end_date DATE NOT NULL, leave_type VARCHAR(50) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING', CHECK(end_date >= start_date),
    FOREIGN KEY(company_id) REFERENCES companies(company_id), FOREIGN KEY(employee_id) REFERENCES hr_employees(employee_id)
);
CREATE TABLE IF NOT EXISTS hr_payroll_runs (
    payroll_run_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, period_start DATE NOT NULL,
    period_end DATE NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    UNIQUE KEY uq_hr_payroll(company_id,period_start,period_end), FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS pos_shifts (
    shift_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, opened_by CHAR(36) NOT NULL,
    opened_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), closed_at DATETIME(6), status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS pos_sales (
    sale_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, shift_id CHAR(36), sale_number VARCHAR(50) NOT NULL,
    sale_date DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), status VARCHAR(20) NOT NULL DEFAULT 'POSTED',
    total_amount DECIMAL(19,4) NOT NULL DEFAULT 0, UNIQUE KEY uq_pos_sale(company_id,sale_number),
    FOREIGN KEY(company_id) REFERENCES companies(company_id), FOREIGN KEY(shift_id) REFERENCES pos_shifts(shift_id)
);
CREATE TABLE IF NOT EXISTS pos_sale_lines (
    line_id CHAR(36) PRIMARY KEY, sale_id CHAR(36) NOT NULL, product_id INT NOT NULL,
    quantity DECIMAL(18,4) NOT NULL, unit_price DECIMAL(19,4) NOT NULL, discount_amount DECIMAL(19,4) NOT NULL DEFAULT 0,
    CHECK(quantity > 0 AND unit_price >= 0), FOREIGN KEY(sale_id) REFERENCES pos_sales(sale_id)
);
CREATE TABLE IF NOT EXISTS pos_payments (
    payment_id CHAR(36) PRIMARY KEY, sale_id CHAR(36) NOT NULL, method VARCHAR(30) NOT NULL,
    amount DECIMAL(19,4) NOT NULL, reference VARCHAR(150), CHECK(amount > 0),
    FOREIGN KEY(sale_id) REFERENCES pos_sales(sale_id)
);
CREATE TABLE IF NOT EXISTS mfg_boms (
    bom_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, product_id INT NOT NULL,
    version VARCHAR(30) NOT NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_mfg_bom(company_id,product_id,version), FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS mfg_bom_lines (
    bom_line_id CHAR(36) PRIMARY KEY, bom_id CHAR(36) NOT NULL, component_product_id INT NOT NULL,
    quantity DECIMAL(18,6) NOT NULL, CHECK(quantity > 0), FOREIGN KEY(bom_id) REFERENCES mfg_boms(bom_id)
);
CREATE TABLE IF NOT EXISTS mfg_work_orders (
    work_order_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, order_number VARCHAR(50) NOT NULL,
    product_id INT NOT NULL, planned_quantity DECIMAL(18,4) NOT NULL, completed_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'PLANNED', UNIQUE KEY uq_mfg_order(company_id,order_number),
    FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS mfg_quality_results (
    quality_result_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, work_order_id CHAR(36),
    test_code VARCHAR(50) NOT NULL, result VARCHAR(30) NOT NULL, measured_value DECIMAL(19,6),
    recorded_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), FOREIGN KEY(company_id) REFERENCES companies(company_id),
    FOREIGN KEY(work_order_id) REFERENCES mfg_work_orders(work_order_id)
);
CREATE TABLE IF NOT EXISTS ai_models (
    model_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, model_code VARCHAR(100) NOT NULL,
    version VARCHAR(30) NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    UNIQUE KEY uq_ai_model(company_id,model_code,version), FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS ai_predictions (
    prediction_id CHAR(36) PRIMARY KEY, company_id CHAR(36) NOT NULL, model_id CHAR(36),
    entity_type VARCHAR(50) NOT NULL, entity_id VARCHAR(100) NOT NULL, score DECIMAL(19,8),
    created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), FOREIGN KEY(company_id) REFERENCES companies(company_id),
    FOREIGN KEY(model_id) REFERENCES ai_models(model_id)
);
CREATE TABLE IF NOT EXISTS audit_events (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY, company_id CHAR(36), actor_id VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL, entity_type VARCHAR(100) NOT NULL, entity_id VARCHAR(100),
    details JSON, occurred_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6), FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
CREATE TABLE IF NOT EXISTS mst_licenses (
    license_id CHAR(36) PRIMARY KEY, company_id CHAR(36), license_key VARCHAR(250) NOT NULL UNIQUE,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', expires_at DATETIME(6), created_at DATETIME(6) NOT NULL DEFAULT UTC_TIMESTAMP(6),
    FOREIGN KEY(company_id) REFERENCES companies(company_id)
);
