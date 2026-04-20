jest.mock('../../src/db');
jest.mock('../../src/services/pedidos.service');

const db      = require('../../src/db');
const service = require('../../src/services/pedidos.service');
const request = require('supertest');
const app     = require('../../src/app');

const mockPedido = { id: 1, producto_id: 1, cantidad: 2, estado: 'pendiente', producto_nombre: 'Notebook' };

beforeEach(() => jest.clearAllMocks());

describe('GET /api/pedidos/info', () => {
  test('200 con db_connected true', async () => {
    db.ping.mockResolvedValue(true);
    service.ESTADOS_VALIDOS = ['pendiente', 'procesado', 'enviado', 'cancelado'];
    const res = await request(app).get('/api/pedidos/info');
    expect(res.status).toBe(200);
    expect(res.body.servicio).toBe('api-pedidos');
    expect(res.body.db_connected).toBe(true);
  });

  test('200 con db_connected false cuando ping falla', async () => {
    db.ping.mockRejectedValue(new Error('timeout'));
    const res = await request(app).get('/api/pedidos/info');
    expect(res.status).toBe(200);
    expect(res.body.db_connected).toBe(false);
  });
});

describe('GET /api/pedidos', () => {
  test('200 con lista', async () => {
    service.getAll.mockResolvedValue([mockPedido]);
    const res = await request(app).get('/api/pedidos');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  test('500 cuando falla el servicio', async () => {
    service.getAll.mockRejectedValue(new Error('DB error'));
    const res = await request(app).get('/api/pedidos');
    expect(res.status).toBe(500);
  });
});

describe('GET /api/pedidos/:id', () => {
  test('200 cuando existe', async () => {
    service.getById.mockResolvedValue(mockPedido);
    const res = await request(app).get('/api/pedidos/1');
    expect(res.status).toBe(200);
  });

  test('404 cuando no existe', async () => {
    service.getById.mockResolvedValue(null);
    const res = await request(app).get('/api/pedidos/999');
    expect(res.status).toBe(404);
  });

  test('500 cuando falla el servicio', async () => {
    service.getById.mockRejectedValue(new Error('DB error'));
    const res = await request(app).get('/api/pedidos/1');
    expect(res.status).toBe(500);
  });
});

describe('POST /api/pedidos', () => {
  test('201 con pedido creado', async () => {
    service.create.mockResolvedValue(mockPedido);
    const res = await request(app)
      .post('/api/pedidos')
      .send({ producto_id: 1, cantidad: 2 });
    expect(res.status).toBe(201);
  });

  test('400 cuando faltan campos', async () => {
    const res = await request(app).post('/api/pedidos').send({ producto_id: 1 });
    expect(res.status).toBe(400);
  });

  test('400 cuando estado es inválido', async () => {
    service.create.mockRejectedValue(new Error('Estado inválido. Permitidos: pendiente'));
    const res = await request(app)
      .post('/api/pedidos')
      .send({ producto_id: 1, cantidad: 1, estado: 'malo' });
    expect(res.status).toBe(400);
  });

  test('500 cuando falla el servicio', async () => {
    service.create.mockRejectedValue(new Error('DB error'));
    const res = await request(app)
      .post('/api/pedidos')
      .send({ producto_id: 1, cantidad: 2 });
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/pedidos/:id', () => {
  test('200 con pedido actualizado', async () => {
    service.update.mockResolvedValue({ ...mockPedido, estado: 'enviado' });
    const res = await request(app).put('/api/pedidos/1').send({ estado: 'enviado' });
    expect(res.status).toBe(200);
  });

  test('404 cuando no existe', async () => {
    service.update.mockResolvedValue(null);
    const res = await request(app).put('/api/pedidos/999').send({ estado: 'enviado' });
    expect(res.status).toBe(404);
  });

  test('400 cuando estado es inválido', async () => {
    service.update.mockRejectedValue(new Error('Estado inválido. Permitidos: pendiente'));
    const res = await request(app).put('/api/pedidos/1').send({ estado: 'malo' });
    expect(res.status).toBe(400);
  });

  test('500 cuando falla el servicio', async () => {
    service.update.mockRejectedValue(new Error('DB error'));
    const res = await request(app).put('/api/pedidos/1').send({ estado: 'enviado' });
    expect(res.status).toBe(500);
  });
});

describe('DELETE /api/pedidos/:id', () => {
  test('200 con pedido eliminado', async () => {
    service.remove.mockResolvedValue(mockPedido);
    const res = await request(app).delete('/api/pedidos/1');
    expect(res.status).toBe(200);
  });

  test('404 cuando no existe', async () => {
    service.remove.mockResolvedValue(null);
    const res = await request(app).delete('/api/pedidos/999');
    expect(res.status).toBe(404);
  });

  test('500 cuando falla el servicio', async () => {
    service.remove.mockRejectedValue(new Error('DB error'));
    const res = await request(app).delete('/api/pedidos/1');
    expect(res.status).toBe(500);
  });
});

describe('Ruta inexistente', () => {
  test('404 en ruta no definida', async () => {
    const res = await request(app).get('/api/xyz');
    expect(res.status).toBe(404);
  });
});
