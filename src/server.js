const express = require("express");
const cors = require("cors");
require("dotenv").config();

const { getPool, sql } = require("./db");

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static("public"));

app.get("/api/health", async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query("SELECT 1 AS ok");
    res.json({ status: "ok", database: result.recordset[0].ok });
  } catch (error) {
    res.status(500).json({ status: "error", message: error.message });
  }
});

app.get("/api/dashboard/summary", async (req, res) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        (SELECT COUNT(*) FROM LumberProducts) AS total_products,
        (SELECT COUNT(*) FROM Inventory WHERE quantity_on_hand <= reorder_level) AS low_stock_items,
        (SELECT COUNT(*) FROM ProductionBatches WHERE batch_status IN ('Scheduled', 'In Progress', 'Blocked')) AS open_batches,
        (SELECT COUNT(*) FROM SupplierDeliveries WHERE received_date IS NULL AND expected_date < CAST(GETDATE() AS date)) AS late_deliveries
    `);

    res.json(result.recordset[0]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/inventory", async (req, res) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        i.inventory_id,
        p.product_id,
        p.sku,
        p.product_type,
        p.grade,
        i.quantity_on_hand,
        i.reorder_level,
        i.location_code,
        i.last_updated
      FROM Inventory i
      JOIN LumberProducts p ON i.product_id = p.product_id
      ORDER BY p.sku
    `);

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put("/api/inventory/:id", async (req, res) => {
  const inventoryId = Number(req.params.id);
  const { quantity_on_hand, reorder_level, location_code } = req.body;

  if (!Number.isInteger(inventoryId)) {
    return res.status(400).json({ message: "Invalid inventory id" });
  }

  if (!Number.isInteger(quantity_on_hand) || !Number.isInteger(reorder_level) || !location_code) {
    return res.status(400).json({
      message: "quantity_on_hand, reorder_level, and location_code are required"
    });
  }

  try {
    const pool = await getPool();

    const result = await pool.request()
      .input("inventoryId", sql.Int, inventoryId)
      .input("quantityOnHand", sql.Int, quantity_on_hand)
      .input("reorderLevel", sql.Int, reorder_level)
      .input("locationCode", sql.NVarChar(50), location_code)
      .query(`
        UPDATE Inventory
        SET
          quantity_on_hand = @quantityOnHand,
          reorder_level = @reorderLevel,
          location_code = @locationCode,
          last_updated = SYSUTCDATETIME()
        WHERE inventory_id = @inventoryId;

        SELECT
          i.inventory_id,
          p.sku,
          p.product_type,
          p.grade,
          i.quantity_on_hand,
          i.reorder_level,
          i.location_code,
          i.last_updated
        FROM Inventory i
        JOIN LumberProducts p ON i.product_id = p.product_id
        WHERE i.inventory_id = @inventoryId;
      `);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: "Inventory record not found" });
    }

    res.json(result.recordset[0]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/alerts/low-stock", async (req, res) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        p.sku,
        p.product_type,
        p.grade,
        i.quantity_on_hand,
        i.reorder_level,
        i.location_code
      FROM Inventory i
      JOIN LumberProducts p ON i.product_id = p.product_id
      WHERE i.quantity_on_hand <= i.reorder_level
      ORDER BY i.quantity_on_hand ASC
    `);

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/production/batches", async (req, res) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        b.batch_id,
        p.sku,
        p.product_type,
        b.batch_status,
        b.planned_quantity,
        b.completed_quantity,
        b.started_at,
        b.completed_at
      FROM ProductionBatches b
      JOIN LumberProducts p ON b.product_id = p.product_id
      ORDER BY b.batch_id DESC
    `);

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/supplier-deliveries", async (req, res) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        d.delivery_id,
        s.supplier_name,
        p.sku,
        p.product_type,
        d.expected_date,
        d.received_date,
        d.quantity_expected,
        d.quantity_received,
        CASE
          WHEN d.received_date IS NULL AND d.expected_date < CAST(GETDATE() AS date)
          THEN 'Late'
          WHEN d.received_date IS NULL
          THEN 'Pending'
          ELSE 'Received'
        END AS delivery_status
      FROM SupplierDeliveries d
      JOIN Suppliers s ON d.supplier_id = s.supplier_id
      JOIN LumberProducts p ON d.product_id = p.product_id
      ORDER BY d.expected_date ASC
    `);

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/machine-events", async (req, res) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        event_id,
        machine_code,
        event_type,
        event_payload,
        created_at
      FROM MachineEvents
      ORDER BY created_at DESC
    `);

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`MillOps Dashboard running on http://localhost:${port}`);
});
