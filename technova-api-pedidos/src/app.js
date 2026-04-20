require('dotenv').config();

const express = require('express');
const pedidosRouter = require('./routes/pedidos.routes');

const app = express();

app.use(express.json());

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use('/api/pedidos', pedidosRouter);

app.use((req, res) => res.status(404).json({ ok: false, error: 'Ruta no encontrada' }));

app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ ok: false, error: 'Error interno del servidor' });
});

module.exports = app;
