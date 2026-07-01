IF DB_ID('MillOps') IS NULL
BEGIN
    CREATE DATABASE MillOps;
END
GO

USE MillOps;
GO

DROP TABLE IF EXISTS MachineEvents;
DROP TABLE IF EXISTS SupplierDeliveries;
DROP TABLE IF EXISTS ProductionBatches;
DROP TABLE IF EXISTS Inventory;
DROP TABLE IF EXISTS LumberProducts;
DROP TABLE IF EXISTS Suppliers;
GO

CREATE TABLE Suppliers (
    supplier_id INT IDENTITY(1,1) PRIMARY KEY,
    supplier_name NVARCHAR(100) NOT NULL,
    contact_email NVARCHAR(150),
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE LumberProducts (
    product_id INT IDENTITY(1,1) PRIMARY KEY,
    sku NVARCHAR(50) NOT NULL UNIQUE,
    product_type NVARCHAR(100) NOT NULL,
    grade NVARCHAR(50) NOT NULL,
    board_feet_per_unit DECIMAL(10,2) NOT NULL CHECK (board_feet_per_unit > 0),
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE TABLE Inventory (
    inventory_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL,
    quantity_on_hand INT NOT NULL CHECK (quantity_on_hand >= 0),
    reorder_level INT NOT NULL CHECK (reorder_level >= 0),
    location_code NVARCHAR(50) NOT NULL,
    last_updated DATETIME2 DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Inventory_Product
        FOREIGN KEY (product_id) REFERENCES LumberProducts(product_id)
);

CREATE TABLE ProductionBatches (
    batch_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL,
    batch_status NVARCHAR(30) NOT NULL
        CHECK (batch_status IN ('Scheduled', 'In Progress', 'Completed', 'Blocked')),
    planned_quantity INT NOT NULL CHECK (planned_quantity > 0),
    completed_quantity INT NOT NULL DEFAULT 0 CHECK (completed_quantity >= 0),
    started_at DATETIME2 NULL,
    completed_at DATETIME2 NULL,
    CONSTRAINT FK_Batches_Product
        FOREIGN KEY (product_id) REFERENCES LumberProducts(product_id)
);

CREATE TABLE SupplierDeliveries (
    delivery_id INT IDENTITY(1,1) PRIMARY KEY,
    supplier_id INT NOT NULL,
    product_id INT NOT NULL,
    expected_date DATE NOT NULL,
    received_date DATE NULL,
    quantity_expected INT NOT NULL CHECK (quantity_expected > 0),
    quantity_received INT NULL CHECK (quantity_received >= 0),
    CONSTRAINT FK_Deliveries_Supplier
        FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id),
    CONSTRAINT FK_Deliveries_Product
        FOREIGN KEY (product_id) REFERENCES LumberProducts(product_id)
);

CREATE TABLE MachineEvents (
    event_id INT IDENTITY(1,1) PRIMARY KEY,
    machine_code NVARCHAR(50) NOT NULL,
    event_type NVARCHAR(50) NOT NULL,
    event_payload NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);

CREATE INDEX IX_Inventory_ProductId ON Inventory(product_id);
CREATE INDEX IX_Inventory_LowStock ON Inventory(quantity_on_hand, reorder_level);
CREATE INDEX IX_Batches_Status ON ProductionBatches(batch_status);
CREATE INDEX IX_Deliveries_ExpectedDate ON SupplierDeliveries(expected_date);
GO

INSERT INTO Suppliers (supplier_name, contact_email)
VALUES
('Northwest Timber Supply', 'orders@nwtimber.example'),
('Cascade Mill Partners', 'supply@cascade.example'),
('Pacific Fasteners', 'dispatch@pacificfasteners.example');

INSERT INTO LumberProducts (sku, product_type, grade, board_feet_per_unit)
VALUES
('DF-2X4-STD-08', 'Douglas Fir 2x4 8ft', 'Standard', 5.33),
('DF-2X6-STD-10', 'Douglas Fir 2x6 10ft', 'Standard', 10.00),
('CED-1X6-PREM-12', 'Cedar 1x6 12ft', 'Premium', 6.00),
('PLY-4X8-CDX', 'Plywood 4x8 CDX', 'CDX', 32.00),
('HEM-2X4-UTIL-08', 'Hemlock 2x4 8ft', 'Utility', 5.33);

INSERT INTO Inventory (product_id, quantity_on_hand, reorder_level, location_code)
VALUES
(1, 42, 50, 'A1'),
(2, 75, 40, 'A2'),
(3, 12, 25, 'B1'),
(4, 30, 20, 'C1'),
(5, 8, 30, 'A3');

INSERT INTO ProductionBatches (product_id, batch_status, planned_quantity, completed_quantity, started_at)
VALUES
(1, 'In Progress', 120, 45, SYSUTCDATETIME()),
(2, 'Scheduled', 80, 0, NULL),
(3, 'Blocked', 40, 0, SYSUTCDATETIME());

INSERT INTO SupplierDeliveries (supplier_id, product_id, expected_date, received_date, quantity_expected, quantity_received)
VALUES
(1, 1, DATEADD(day, -2, CAST(GETDATE() AS date)), NULL, 100, NULL),
(2, 3, DATEADD(day, 2, CAST(GETDATE() AS date)), NULL, 60, NULL),
(3, 5, DATEADD(day, -1, CAST(GETDATE() AS date)), NULL, 40, NULL);

INSERT INTO MachineEvents (machine_code, event_type, event_payload)
VALUES
('SAW-01', 'CycleComplete', '{"batchId":1,"durationSeconds":42}'),
('SAW-01', 'JamDetected', '{"severity":"medium","station":"feed"}'),
('PLANER-02', 'MaintenanceNotice', '{"hoursRemaining":12}');
GO
