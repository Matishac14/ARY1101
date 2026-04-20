const mockConnection = {
  ping: jest.fn().mockResolvedValue(true),
  release: jest.fn(),
};
const mockPool = {
  execute: jest.fn(),
  getConnection: jest.fn().mockResolvedValue(mockConnection),
  end: jest.fn().mockResolvedValue(true),
};

jest.doMock('mysql2/promise', () => ({
  createPool: jest.fn().mockReturnValue(mockPool),
}));

let db;

beforeAll(() => {
  db = require('../../src/db');
});

beforeEach(() => jest.clearAllMocks());

afterAll(async () => {
  await db.closePool();
});

describe('db.query', () => {
  test('ejecuta SQL y retorna filas', async () => {
    mockPool.execute.mockResolvedValue([[{ id: 1 }]]);
    const rows = await db.query('SELECT 1', []);
    expect(rows).toEqual([{ id: 1 }]);
  });

  test('sin parámetros usa arreglo vacío', async () => {
    mockPool.execute.mockResolvedValue([[{ ok: 1 }]]);
    const rows = await db.query('SELECT 1');
    expect(mockPool.execute).toHaveBeenCalledWith('SELECT 1', []);
    expect(rows).toBeDefined();
  });
});

describe('db.ping', () => {
  test('hace ping y libera la conexión', async () => {
    const result = await db.ping();
    expect(mockConnection.ping).toHaveBeenCalled();
    expect(result).toBe(true);
  });
});

describe('db.closePool', () => {
  test('cierra el pool', async () => {
    mockPool.execute.mockResolvedValue([[{ id: 1 }]]);
    await db.query('SELECT 1');
    await db.closePool();
    expect(mockPool.end).toHaveBeenCalled();
  });

  test('no falla si ya está cerrado', async () => {
    await expect(db.closePool()).resolves.toBeUndefined();
  });
});
