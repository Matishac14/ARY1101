const db = require('../db');

async function getAll() {
  return db.query('SELECT * FROM productos ORDER BY id');
}

async function getById(id) {
  const rows = await db.query('SELECT * FROM productos WHERE id = ?', [id]);
  return rows[0] || null;
}

async function create({ nombre, precio, stock, categoria }) {
  const result = await db.query(
    'INSERT INTO productos (nombre, precio, stock, categoria) VALUES (?, ?, ?, ?)',
    [nombre, precio, stock ?? 0, categoria ?? null]
  );
  return getById(result.insertId);
}

async function update(id, { nombre, precio, stock, categoria }) {
  const fields = [];
  const values = [];

  if (nombre    !== undefined) { fields.push('nombre = ?');    values.push(nombre); }
  if (precio    !== undefined) { fields.push('precio = ?');    values.push(precio); }
  if (stock     !== undefined) { fields.push('stock = ?');     values.push(stock); }
  if (categoria !== undefined) { fields.push('categoria = ?'); values.push(categoria); }

  if (fields.length === 0) return getById(id);

  values.push(id);
  await db.query(`UPDATE productos SET ${fields.join(', ')} WHERE id = ?`, values);
  return getById(id);
}

async function remove(id) {
  const producto = await getById(id);
  if (!producto) return null;
  await db.query('DELETE FROM productos WHERE id = ?', [id]);
  return producto;
}

module.exports = { getAll, getById, create, update, remove };
