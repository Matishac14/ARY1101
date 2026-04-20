jest.mock('../../src/db');

const db = require('../../src/db');
const service = require('../../src/services/productos.service');

const mockProducto = { id: 1, nombre: 'Notebook', precio: 649990, stock: 10, categoria: 'Computadores' };

beforeEach(() => jest.clearAllMocks());

describe('ProductosService.getAll', () => {
  test('retorna lista de productos', async () => {
    db.query.mockResolvedValue([mockProducto]);
    const result = await service.getAll();
    expect(db.query).toHaveBeenCalledWith('SELECT * FROM productos ORDER BY id');
    expect(result).toEqual([mockProducto]);
  });
});

describe('ProductosService.getById', () => {
  test('retorna producto existente', async () => {
    db.query.mockResolvedValue([mockProducto]);
    const result = await service.getById(1);
    expect(result).toEqual(mockProducto);
  });

  test('retorna null si no existe', async () => {
    db.query.mockResolvedValue([]);
    const result = await service.getById(999);
    expect(result).toBeNull();
  });
});

describe('ProductosService.create', () => {
  test('inserta y retorna el producto creado', async () => {
    db.query
      .mockResolvedValueOnce({ insertId: 2 })
      .mockResolvedValueOnce([{ ...mockProducto, id: 2 }]);

    const result = await service.create({ nombre: 'Notebook', precio: 649990, stock: 10, categoria: 'Computadores' });
    expect(db.query).toHaveBeenCalledTimes(2);
    expect(result.id).toBe(2);
  });

  test('usa stock 0 y categoria null por defecto', async () => {
    db.query
      .mockResolvedValueOnce({ insertId: 3 })
      .mockResolvedValueOnce([{ id: 3, nombre: 'Mouse', precio: 9990, stock: 0, categoria: null }]);

    const result = await service.create({ nombre: 'Mouse', precio: 9990 });
    expect(db.query).toHaveBeenNthCalledWith(
      1,
      'INSERT INTO productos (nombre, precio, stock, categoria) VALUES (?, ?, ?, ?)',
      ['Mouse', 9990, 0, null]
    );
    expect(result.stock).toBe(0);
  });
});

describe('ProductosService.update', () => {
  test('actualiza solo stock', async () => {
    db.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce([{ ...mockProducto, stock: 20 }]);

    const result = await service.update(1, { stock: 20 });
    expect(db.query).toHaveBeenNthCalledWith(
      1,
      'UPDATE productos SET stock = ? WHERE id = ?',
      [20, 1]
    );
    expect(result.stock).toBe(20);
  });

  test('actualiza nombre, precio y categoria', async () => {
    db.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce([{ ...mockProducto, nombre: 'Nuevo', precio: 999, categoria: 'Test' }]);

    const result = await service.update(1, { nombre: 'Nuevo', precio: 999, categoria: 'Test' });
    const [sql, vals] = db.query.mock.calls[0];
    expect(sql).toContain('nombre = ?');
    expect(sql).toContain('precio = ?');
    expect(sql).toContain('categoria = ?');
    expect(vals).toContain('Nuevo');
    expect(result.nombre).toBe('Nuevo');
  });

  test('actualiza todos los campos a la vez', async () => {
    db.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce([mockProducto]);

    await service.update(1, { nombre: 'X', precio: 1, stock: 2, categoria: 'Y' });
    const [sql] = db.query.mock.calls[0];
    expect(sql).toContain('nombre = ?');
    expect(sql).toContain('precio = ?');
    expect(sql).toContain('stock = ?');
    expect(sql).toContain('categoria = ?');
  });

  test('sin campos retorna producto sin query UPDATE', async () => {
    db.query.mockResolvedValue([mockProducto]);
    const result = await service.update(1, {});
    expect(result).toEqual(mockProducto);
    expect(db.query).toHaveBeenCalledTimes(1);
  });
});

describe('ProductosService.remove', () => {
  test('elimina y retorna producto borrado', async () => {
    db.query
      .mockResolvedValueOnce([mockProducto])
      .mockResolvedValueOnce({});

    const result = await service.remove(1);
    expect(result).toEqual(mockProducto);
    expect(db.query).toHaveBeenCalledTimes(2);
  });

  test('retorna null si el producto no existe', async () => {
    db.query.mockResolvedValue([]);
    const result = await service.remove(999);
    expect(result).toBeNull();
  });
});
