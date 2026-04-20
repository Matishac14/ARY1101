const service = require('../services/productos.service');
const db      = require('../db');

async function info(req, res) {
  let db_connected = false;
  try {
    await db.ping();
    db_connected = true;
  } catch (_) {}

  res.json({
    servicio:      'api-productos',
    version:       '1.0.0',
    alumno_nombre: process.env.ALUMNO_NOMBRE  || 'Sin configurar',
    alumno_rut:    process.env.ALUMNO_RUT     || 'Sin configurar',
    alumno_seccion:process.env.ALUMNO_SECCION || 'Sin configurar',
    db_connected,
  });
}

async function getAll(req, res) {
  try {
    const data = await service.getAll();
    res.json({ ok: true, data });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

async function getOne(req, res) {
  try {
    const producto = await service.getById(parseInt(req.params.id, 10));
    if (!producto) return res.status(404).json({ ok: false, error: 'Producto no encontrado' });
    res.json({ ok: true, data: producto });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

async function create(req, res) {
  const { nombre, precio, stock, categoria } = req.body;
  if (!nombre || precio === undefined) {
    return res.status(400).json({ ok: false, error: 'nombre y precio son requeridos' });
  }
  try {
    const producto = await service.create({ nombre, precio, stock, categoria });
    res.status(201).json({ ok: true, data: producto });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

async function update(req, res) {
  try {
    const producto = await service.update(parseInt(req.params.id, 10), req.body);
    if (!producto) return res.status(404).json({ ok: false, error: 'Producto no encontrado' });
    res.json({ ok: true, data: producto });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

async function remove(req, res) {
  try {
    const producto = await service.remove(parseInt(req.params.id, 10));
    if (!producto) return res.status(404).json({ ok: false, error: 'Producto no encontrado' });
    res.json({ ok: true, data: producto });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

module.exports = { info, getAll, getOne, create, update, remove };
