jest.mock('../../src/db');

const db = require('../../src/db');
const service = require('../../src/services/pedidos.service');

const mockPedido = { id: 1, producto_id: 1, cantidad: 2, estado: 'pendiente', producto_nombre: 'Notebook' };

beforeEach(() => jest.clearAllMocks());

describe('PedidosService.getAll', () => {
  test('retorna lista de pedidos con JOIN', async () => {
    db.query.mockResolvedValue([mockPedido]);
    const result = await service.getAll();
    expect(db.query).toHaveBeenCalledTimes(1);
    expect(result).toEqual([mockPedido]);
  });
});

describe('PedidosService.getById', () => {
  test('retorna pedido existente', async () => {
    db.query.mockResolvedValue([mockPedido]);
    const result = await service.getById(1);
    expect(result).toEqual(mockPedido);
  });

  test('retorna null si no existe', async () => {
    db.query.mockResolvedValue([]);
    const result = await service.getById(999);
    expect(result).toBeNull();
  });
});

describe('PedidosService.create', () => {
  test('inserta y retorna el pedido creado', async () => {
    db.query
      .mockResolvedValueOnce({ insertId: 2 })
      .mockResolvedValueOnce([{ ...mockPedido, id: 2 }]);

    const result = await service.create({ producto_id: 1, cantidad: 3, estado: 'pendiente' });
    expect(db.query).toHaveBeenCalledTimes(2);
    expect(result.id).toBe(2);
  });

  test('usa estado "pendiente" por defecto', async () => {
    db.query
      .mockResolvedValueOnce({ insertId: 3 })
      .mockResolvedValueOnce([{ ...mockPedido, id: 3 }]);

    await service.create({ producto_id: 1, cantidad: 1 });
    const [sql, vals] = db.query.mock.calls[0];
    expect(vals[2]).toBe('pendiente');
  });

  test('lanza error con estado inválido', async () => {
    await expect(service.create({ producto_id: 1, cantidad: 1, estado: 'invalido' }))
      .rejects.toThrow('Estado inválido');
  });
});

describe('PedidosService.update', () => {
  test('actualiza estado del pedido', async () => {
    db.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce([{ ...mockPedido, estado: 'enviado' }]);

    const result = await service.update(1, { estado: 'enviado' });
    expect(result.estado).toBe('enviado');
  });

  test('actualiza producto_id, cantidad y estado', async () => {
    db.query
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce([mockPedido]);

    await service.update(1, { producto_id: 2, cantidad: 5, estado: 'procesado' });
    const [sql, vals] = db.query.mock.calls[0];
    expect(sql).toContain('producto_id = ?');
    expect(sql).toContain('cantidad = ?');
    expect(sql).toContain('estado = ?');
  });

  test('sin campos retorna pedido sin query UPDATE', async () => {
    db.query.mockResolvedValue([mockPedido]);
    const result = await service.update(1, {});
    expect(result).toEqual(mockPedido);
    expect(db.query).toHaveBeenCalledTimes(1);
  });

  test('lanza error con estado inválido en update', async () => {
    await expect(service.update(1, { estado: 'xyz' }))
      .rejects.toThrow('Estado inválido');
  });
});

describe('PedidosService.remove', () => {
  test('elimina y retorna pedido borrado', async () => {
    db.query
      .mockResolvedValueOnce([mockPedido])
      .mockResolvedValueOnce({});

    const result = await service.remove(1);
    expect(result).toEqual(mockPedido);
  });

  test('retorna null si no existe', async () => {
    db.query.mockResolvedValue([]);
    const result = await service.remove(999);
    expect(result).toBeNull();
  });
});
