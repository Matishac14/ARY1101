const service = require('../services/pedidos.service');
const db      = require('../db');

async function info(req, res) {
  let db_connected = false;
  try {
    await db.ping();
    db_connected = true;
  } catch (_) {}

  res.json({
    servicio:       'api-pedidos',
    version:        '1.0.0',
    alumno_nombre:  process.env.ALUMNO_NOMBRE  || 'Sin configurar',
    alumno_rut:     process.env.ALUMNO_RUT     || 'Sin configurar',
    alumno_seccion: process.env.ALUMNO_SECCION || 'Sin configurar',
    estados_validos: service.ESTADOS_VALIDOS,
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
    const pedido = await service.getById(parseInt(req.params.id, 10));
    if (!pedido) return res.status(404).json({ ok: false, error: 'Pedido no encontrado' });
    res.json({ ok: true, data: pedido });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

async function create(req, res) {
  const { producto_id, cantidad, estado } = req.body;
  if (!producto_id || !cantidad) {
    return res.status(400).json({ ok: false, error: 'producto_id y cantidad son requeridos' });
  }
  try {
    const pedido = await service.create({ producto_id, cantidad, estado });
    res.status(201).json({ ok: true, data: pedido });
  } catch (err) {
    const status = err.message.startsWith('Estado inválido') ? 400 : 500;
    res.status(status).json({ ok: false, error: err.message });
  }
}

async function update(req, res) {
  try {
    const pedido = await service.update(parseInt(req.params.id, 10), req.body);
    if (!pedido) return res.status(404).json({ ok: false, error: 'Pedido no encontrado' });
    res.json({ ok: true, data: pedido });
  } catch (err) {
    const status = err.message.startsWith('Estado inválido') ? 400 : 500;
    res.status(status).json({ ok: false, error: err.message });
  }
}

async function remove(req, res) {
  try {
    const pedido = await service.remove(parseInt(req.params.id, 10));
    if (!pedido) return res.status(404).json({ ok: false, error: 'Pedido no encontrado' });
    res.json({ ok: true, data: pedido });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

module.exports = { info, getAll, getOne, create, update, remove };
