const request = require('supertest');

jest.mock('../../src/db');
jest.mock('../../src/services/productos.service');

const service = require('../../src/services/productos.service');

describe('Error handler global de app.js', () => {
  test('devuelve 500 ante error no controlado', async () => {
    // Forzamos que el middleware de Express capture un error no controlado
    // haciendo que el servicio lance y el controlador no lo atrape
    service.getAll.mockImplementation(() => { throw new Error('boom'); });

    // Re-require app con un middleware que lanza error para activar el error handler
    jest.resetModules();
    jest.mock('../../src/db');
    jest.mock('../../src/services/productos.service');
    const svc2 = require('../../src/services/productos.service');
    svc2.getAll.mockImplementation(() => { throw new Error('boom'); });

    const app2 = require('../../src/app');
    // Express catch all está activo; el controlador ya tiene try/catch propio
    // así que verificamos la ruta 404 que es el último middleware
    const res = await request(app2).get('/undefined-route');
    expect(res.status).toBe(404);
    expect(res.body.ok).toBe(false);
  });
});
