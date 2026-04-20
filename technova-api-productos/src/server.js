require('dotenv').config();

const app  = require('./app');
const { closePool } = require('./db');

const PORT = parseInt(process.env.PORT || '3001', 10);

const server = app.listen(PORT, () => {
  console.log(`[api-productos] escuchando en puerto ${PORT}`);
});

process.on('SIGTERM', async () => {
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
});

module.exports = server;
