import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { PedidosService } from './pedidos.service';
import { Pedido, ApiInfo } from '../models/technova.models';

const mockPedido: Pedido = { id: 1, producto_id: 1, cantidad: 2, estado: 'pendiente', producto_nombre: 'Notebook' };
const mockInfo: ApiInfo = { servicio: 'api-pedidos', version: '1.0.0', alumno_nombre: 'Juan', alumno_rut: '1-9', alumno_seccion: 'ARY1101', db_connected: true, estados_validos: ['pendiente'] };

describe('PedidosService', () => {
  let service: PedidosService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [HttpClientTestingModule] });
    service = TestBed.inject(PedidosService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('getInfo retorna info de la API', () => {
    service.getInfo().subscribe(info => expect(info.servicio).toBe('api-pedidos'));
    http.expectOne('/api/pedidos/info').flush(mockInfo);
  });

  it('getAll retorna lista de pedidos', () => {
    service.getAll().subscribe(list => expect(list).toHaveLength(1));
    http.expectOne('/api/pedidos').flush({ ok: true, data: [mockPedido] });
  });

  it('getById retorna un pedido', () => {
    service.getById(1).subscribe(p => expect(p.id).toBe(1));
    http.expectOne('/api/pedidos/1').flush({ ok: true, data: mockPedido });
  });

  it('create hace POST', () => {
    service.create({ producto_id: 1, cantidad: 2, estado: 'pendiente' }).subscribe(p => expect(p).toBeDefined());
    const req = http.expectOne('/api/pedidos');
    expect(req.request.method).toBe('POST');
    req.flush({ ok: true, data: mockPedido });
  });

  it('update hace PUT', () => {
    service.update(1, { estado: 'enviado' }).subscribe(p => expect(p).toBeDefined());
    const req = http.expectOne('/api/pedidos/1');
    expect(req.request.method).toBe('PUT');
    req.flush({ ok: true, data: { ...mockPedido, estado: 'enviado' } });
  });

  it('delete hace DELETE', () => {
    service.delete(1).subscribe(p => expect(p.id).toBe(1));
    const req = http.expectOne('/api/pedidos/1');
    expect(req.request.method).toBe('DELETE');
    req.flush({ ok: true, data: mockPedido });
  });
});
