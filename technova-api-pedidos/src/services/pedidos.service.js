const ESTADOS_VALIDOS = ['pendiente', 'procesado', 'enviado', 'cancelado'];

const db = require('../db');

async function getAll() {
  return db.query(
    `SELECT p.*, pr.nombre AS producto_nombre
     FROM pedidos p
     LEFT JOIN productos pr ON p.producto_id = pr.id
     ORDER BY p.id`
  );
}

async function getById(id) {
  const rows = await db.query(
    `SELECT p.*, pr.nombre AS producto_nombre
     FROM pedidos p
     LEFT JOIN productos pr ON p.producto_id = pr.id
     WHERE p.id = ?`,
    [id]
  );
  return rows[0] || null;
}

async function create({ producto_id, cantidad, estado }) {
  if (estado && !ESTADOS_VALIDOS.includes(estado)) {
    throw new Error(`Estado inválido. Permitidos: ${ESTADOS_VALIDOS.join(', ')}`);
  }
  const result = await db.query(
    'INSERT INTO pedidos (producto_id, cantidad, estado) VALUES (?, ?, ?)',
    [producto_id, cantidad, estado ?? 'pendiente']
  );
  return getById(result.insertId);
}

async function update(id, { producto_id, cantidad, estado }) {
  const fields = [];
  const values = [];

  if (producto_id !== undefined) { fields.push('producto_id = ?'); values.push(producto_id); }
  if (cantidad    !== undefined) { fields.push('cantidad = ?');    values.push(cantidad); }
  if (estado      !== undefined) {
    if (!ESTADOS_VALIDOS.includes(estado)) {
      throw new Error(`Estado inválido. Permitidos: ${ESTADOS_VALIDOS.join(', ')}`);
    }
    fields.push('estado = ?');
    values.push(estado);
  }

  if (fields.length === 0) return getById(id);

  values.push(id);
  await db.query(`UPDATE pedidos SET ${fields.join(', ')} WHERE id = ?`, values);
  return getById(id);
}

async function remove(id) {
  const pedido = await getById(id);
  if (!pedido) return null;
  await db.query('DELETE FROM pedidos WHERE id = ?', [id]);
  return pedido;
}

module.exports = { getAll, getById, create, update, remove, ESTADOS_VALIDOS };
