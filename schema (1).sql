-- Material management schema (PostgreSQL), derived from the ER diagram

-- ===== Access and Security =====
CREATE TABLE roles (
    role_id      SERIAL PRIMARY KEY,
    role_name    VARCHAR(50) NOT NULL UNIQUE,
    description  TEXT
);

CREATE TABLE users (
    user_id        SERIAL PRIMARY KEY,
    role_id        INT NOT NULL REFERENCES roles(role_id),
    full_name      VARCHAR(150) NOT NULL,
    username       VARCHAR(50) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    email          VARCHAR(150) UNIQUE,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_sessions (
    session_id  SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(user_id),
    token_hash  VARCHAR(255) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP NOT NULL
);

CREATE TABLE audit_logs (
    log_id     SERIAL PRIMARY KEY,
    user_id    INT REFERENCES users(user_id),
    action     VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id  INT,
    logged_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ===== Projects =====
CREATE TABLE clients (
    client_id       SERIAL PRIMARY KEY,
    client_name     VARCHAR(150) NOT NULL,
    contact_person  VARCHAR(150),
    contact_number  VARCHAR(30)
);

CREATE TABLE projects (
    project_id    SERIAL PRIMARY KEY,
    client_id     INT NOT NULL REFERENCES clients(client_id),
    manager_id    INT NOT NULL REFERENCES users(user_id),
    project_name  VARCHAR(200) NOT NULL,
    location      VARCHAR(255),
    status        VARCHAR(30) NOT NULL DEFAULT 'planned',
    start_date    DATE,
    end_date      DATE
);

-- ===== Materials =====
CREATE TABLE units (
    unit_id       SERIAL PRIMARY KEY,
    unit_name     VARCHAR(50) NOT NULL UNIQUE,
    abbreviation  VARCHAR(10) NOT NULL
);

CREATE TABLE categories (
    category_id    SERIAL PRIMARY KEY,
    category_name  VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE materials (
    material_id       SERIAL PRIMARY KEY,
    category_id       INT NOT NULL REFERENCES categories(category_id),
    unit_id           INT NOT NULL REFERENCES units(unit_id),
    material_name     VARCHAR(200) NOT NULL,
    sku               VARCHAR(50) NOT NULL UNIQUE,
    unit_cost         NUMERIC(12,2) NOT NULL DEFAULT 0,
    quantity_on_hand  NUMERIC(12,2) NOT NULL DEFAULT 0,
    min_stock_level   NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE project_materials (
    project_material_id  SERIAL PRIMARY KEY,
    project_id           INT NOT NULL REFERENCES projects(project_id),
    material_id          INT NOT NULL REFERENCES materials(material_id),
    quantity_required    NUMERIC(12,2) NOT NULL,
    UNIQUE (project_id, material_id)
);

-- ===== Material Requests =====
CREATE TABLE request_statuses (
    status_id    SERIAL PRIMARY KEY,
    status_name  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE material_requests (
    request_id    SERIAL PRIMARY KEY,
    project_id    INT NOT NULL REFERENCES projects(project_id),
    requested_by  INT NOT NULL REFERENCES users(user_id),
    reviewed_by   INT REFERENCES users(user_id),
    status_id     INT NOT NULL REFERENCES request_statuses(status_id),
    remarks       TEXT,
    requested_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at   TIMESTAMP
);

CREATE TABLE request_items (
    item_id             SERIAL PRIMARY KEY,
    request_id          INT NOT NULL REFERENCES material_requests(request_id),
    material_id         INT NOT NULL REFERENCES materials(material_id),
    quantity_requested  NUMERIC(12,2) NOT NULL,
    quantity_approved   NUMERIC(12,2)
);

CREATE TABLE request_status_history (
    history_id  SERIAL PRIMARY KEY,
    request_id  INT NOT NULL REFERENCES material_requests(request_id),
    status_id   INT NOT NULL REFERENCES request_statuses(status_id),
    changed_by  INT NOT NULL REFERENCES users(user_id),
    changed_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarks     TEXT
);

CREATE TABLE material_releases (
    release_id   SERIAL PRIMARY KEY,
    request_id   INT NOT NULL REFERENCES material_requests(request_id),
    released_by  INT NOT NULL REFERENCES users(user_id),
    released_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE release_items (
    release_item_id   SERIAL PRIMARY KEY,
    release_id        INT NOT NULL REFERENCES material_releases(release_id),
    item_id           INT NOT NULL REFERENCES request_items(item_id),
    quantity_released NUMERIC(12,2) NOT NULL
);

-- ===== Procurement =====
CREATE TABLE suppliers (
    supplier_id     SERIAL PRIMARY KEY,
    supplier_name   VARCHAR(200) NOT NULL,
    contact_person  VARCHAR(150),
    contact_number  VARCHAR(30),
    email           VARCHAR(150),
    address         TEXT
);

CREATE TABLE supplier_materials (
    supplier_material_id  SERIAL PRIMARY KEY,
    supplier_id           INT NOT NULL REFERENCES suppliers(supplier_id),
    material_id           INT NOT NULL REFERENCES materials(material_id),
    unit_price            NUMERIC(12,2) NOT NULL,
    UNIQUE (supplier_id, material_id)
);

CREATE TABLE purchase_orders (
    po_id          SERIAL PRIMARY KEY,
    supplier_id    INT NOT NULL REFERENCES suppliers(supplier_id),
    request_id     INT REFERENCES material_requests(request_id),
    created_by     INT NOT NULL REFERENCES users(user_id),
    status         VARCHAR(30) NOT NULL DEFAULT 'draft',
    order_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date  DATE
);

CREATE TABLE purchase_order_items (
    po_item_id        SERIAL PRIMARY KEY,
    po_id             INT NOT NULL REFERENCES purchase_orders(po_id),
    material_id       INT NOT NULL REFERENCES materials(material_id),
    quantity_ordered  NUMERIC(12,2) NOT NULL,
    unit_price        NUMERIC(12,2) NOT NULL
);

CREATE TABLE goods_receipts (
    receipt_id   SERIAL PRIMARY KEY,
    po_id        INT NOT NULL REFERENCES purchase_orders(po_id),
    received_by  INT NOT NULL REFERENCES users(user_id),
    received_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE receipt_items (
    receipt_item_id    SERIAL PRIMARY KEY,
    receipt_id         INT NOT NULL REFERENCES goods_receipts(receipt_id),
    po_item_id         INT NOT NULL REFERENCES purchase_order_items(po_item_id),
    quantity_received  NUMERIC(12,2) NOT NULL
);

-- ===== Inventory and Analytics =====
CREATE TABLE inventory_transactions (
    transaction_id    SERIAL PRIMARY KEY,
    material_id       INT NOT NULL REFERENCES materials(material_id),
    user_id           INT NOT NULL REFERENCES users(user_id),
    transaction_type  VARCHAR(30) NOT NULL,  -- e.g. receipt, release, adjustment
    quantity          NUMERIC(12,2) NOT NULL,
    reference_type    VARCHAR(50),           -- e.g. goods_receipts, material_releases
    reference_id      INT,
    transaction_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE low_stock_alerts (
    alert_id          SERIAL PRIMARY KEY,
    material_id       INT NOT NULL REFERENCES materials(material_id),
    quantity_at_alert NUMERIC(12,2) NOT NULL,
    min_stock_level   NUMERIC(12,2) NOT NULL,
    status            VARCHAR(30) NOT NULL DEFAULT 'open',
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE demand_forecasts (
    forecast_id        SERIAL PRIMARY KEY,
    material_id        INT NOT NULL REFERENCES materials(material_id),
    period_start       DATE NOT NULL,
    period_end         DATE NOT NULL,
    avg_monthly_usage  NUMERIC(12,2),
    forecast_quantity  NUMERIC(12,2),
    generated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Helpful indexes on foreign keys
CREATE INDEX idx_users_role              ON users(role_id);
CREATE INDEX idx_projects_client         ON projects(client_id);
CREATE INDEX idx_materials_category      ON materials(category_id);
CREATE INDEX idx_requests_project        ON material_requests(project_id);
CREATE INDEX idx_requests_status         ON material_requests(status_id);
CREATE INDEX idx_request_items_request   ON request_items(request_id);
CREATE INDEX idx_po_supplier             ON purchase_orders(supplier_id);
CREATE INDEX idx_inv_tx_material         ON inventory_transactions(material_id);
CREATE INDEX idx_forecast_material       ON demand_forecasts(material_id);
