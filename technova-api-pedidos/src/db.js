require('dotenv').config();

const mysql = require('mysql2/promise');

const config = {
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT || '3306', 10),
  database: process.env.DB_NAME     || 'technova',
  user:     process.env.DB_USER     || 'technova_user',
  password: process.env.DB_PASSWORD || 'technova_pass',
  waitForConnections: true,
  connectionLimit:    10,
  queueLimit:         0,
};

let pool = null;

function getPool() {
  if (!pool) {
    pool = mysql.createPool(config);
  }
  return pool;
}

async function query(sql, params = []) {
  const [rows] = await getPool().execute(sql, params);
  return rows;
}

async function ping() {
  const conn = await getPool().getConnection();
  await conn.ping();
  conn.release();
  return true;
}

async function closePool() {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

module.exports = { query, ping, closePool, getPool };
