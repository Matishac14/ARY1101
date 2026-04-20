jest.mock('../../src/db');
jest.mock('../../src/services/productos.service');

const db      = require('../../src/db');
const service = require('../../src/services/productos.service');
const request = require('supertest');
const app     = require('../../src/app');

const mockProducto = { id: 1, nombre: 'Notebook', precio: 649990, stock: 10, categoria: 'Computadores' };

beforeEach(() => jest.clearAllMocks());

describe('GET /api/productos/info', () => {
  test('200 con db_connected true cuando ping OK', async () => {
    db.ping.mockResolvedValue(true);
    const res = await request(app).get('/api/productos/info');
    expect(res.status).toBe(200);
    expect(res.body.servicio).toBe('api-productos');
    expect(res.body.db_connected).toBe(true);
  });

  test('200 con db_connected false cuando ping falla', async () => {
    db.ping.mockRejectedValue(new Error('timeout'));
    const res = await request(app).get('/api/productos/info');
    expect(res.status).toBe(200);
    expect(res.body.db_connected).toBe(false);
  });
});

describe('GET /api/productos', () => {
  test('200 con lista de productos', async () => {
    service.getAll.mockResolvedValue([mockProducto]);
    const res = await request(app).get('/api/productos');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.data).toHaveLength(1);
  });

  test('500 cuando el servicio lanza error', async () => {
    service.getAll.mockRejectedValue(new Error('DB error'));
    const res = await request(app).get('/api/productos');
    expect(res.status).toBe(500);
    expect(res.body.ok).toBe(false);
  });
});

describe('GET /api/productos/:id', () => {
  test('200 cuando producto existe', async () => {
    service.getById.mockResolvedValue(mockProducto);
    const res = await request(app).get('/api/productos/1');
    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(1);
  });

  test('404 cuando no existe', async () => {
    service.getById.mockResolvedValue(null);
    const res = await request(app).get('/api/productos/999');
    expect(res.status).toBe(404);
  });

  test('500 cuando el servicio lanza error', async () => {
    service.getById.mockRejectedValue(new Error('DB error'));
    const res = await request(app).get('/api/productos/1');
    expect(res.status).toBe(500);
  });
});

describe('POST /api/productos', () => {
  test('201 con producto creado', async () => {
    service.create.mockResolvedValue(mockProducto);
    const res = await request(app)
      .post('/api/productos')
      .send({ nombre: 'Notebook', precio: 649990 });
    expect(res.status).toBe(201);
    expect(res.body.ok).toBe(true);
  });

  test('400 cuando faltan campos requeridos', async () => {
    const res = await request(app).post('/api/productos').send({ nombre: 'Notebook' });
    expect(res.status).toBe(400);
    expect(res.body.ok).toBe(false);
  });

  test('500 cuando el servicio lanza error', async () => {
    service.create.mockRejectedValue(new Error('DB error'));
    const res = await request(app)
      .post('/api/productos')
      .send({ nombre: 'Notebook', precio: 9990 });
    expect(res.status).toBe(500);
  });
});

describe('PUT /api/productos/:id', () => {
  test('200 con producto actualizado', async () => {
    service.update.mockResolvedValue({ ...mockProducto, stock: 99 });
    const res = await request(app).put('/api/productos/1').send({ stock: 99 });
    expect(res.status).toBe(200);
    expect(res.body.data.stock).toBe(99);
  });

  test('404 cuando no existe', async () => {
    service.update.mockResolvedValue(null);
    const res = await request(app).put('/api/productos/999').send({ stock: 1 });
    expect(res.status).toBe(404);
  });

  test('500 cuando el servicio lanza error', async () => {
    service.update.mockRejectedValue(new Error('DB error'));
    const res = await request(app).put('/api/productos/1').send({ stock: 1 });
    expect(res.status).toBe(500);
  });
});

describe('DELETE /api/productos/:id', () => {
  test('200 con producto eliminado', async () => {
    service.remove.mockResolvedValue(mockProducto);
    const res = await request(app).delete('/api/productos/1');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  test('404 cuando no existe', async () => {
    service.remove.mockResolvedValue(null);
    const res = await request(app).delete('/api/productos/999');
    expect(res.status).toBe(404);
  });

  test('500 cuando el servicio lanza error', async () => {
    service.remove.mockRejectedValue(new Error('DB error'));
    const res = await request(app).delete('/api/productos/1');
    expect(res.status).toBe(500);
  });
});

describe('Ruta inexistente', () => {
  test('404 en ruta no definida', async () => {
    const res = await request(app).get('/api/xyz');
    expect(res.status).toBe(404);
  });
});
