import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { ProductosService } from './productos.service';
import { Producto, ApiInfo } from '../models/technova.models';

const mockProducto: Producto = { id: 1, nombre: 'Notebook', precio: 649990, stock: 10, categoria: 'Computadores' };
const mockInfo: ApiInfo = { servicio: 'api-productos', version: '1.0.0', alumno_nombre: 'Juan', alumno_rut: '1-9', alumno_seccion: 'ARY1101', db_connected: true };

describe('ProductosService', () => {
  let service: ProductosService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [HttpClientTestingModule] });
    service = TestBed.inject(ProductosService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('getInfo retorna info de la API', () => {
    service.getInfo().subscribe(info => {
      expect(info.servicio).toBe('api-productos');
      expect(info.db_connected).toBe(true);
    });
    http.expectOne('/api/productos/info').flush(mockInfo);
  });

  it('getAll retorna lista de productos', () => {
    service.getAll().subscribe(list => expect(list).toHaveLength(1));
    http.expectOne('/api/productos').flush({ ok: true, data: [mockProducto] });
  });

  it('getById retorna un producto', () => {
    service.getById(1).subscribe(p => expect(p.id).toBe(1));
    http.expectOne('/api/productos/1').flush({ ok: true, data: mockProducto });
  });

  it('create hace POST y retorna producto creado', () => {
    service.create({ nombre: 'Notebook', precio: 649990, stock: 10, categoria: null })
      .subscribe(p => expect(p.id).toBe(1));
    const req = http.expectOne('/api/productos');
    expect(req.request.method).toBe('POST');
    req.flush({ ok: true, data: mockProducto });
  });

  it('update hace PUT y retorna producto actualizado', () => {
    service.update(1, { stock: 20 }).subscribe(p => expect(p).toBeDefined());
    const req = http.expectOne('/api/productos/1');
    expect(req.request.method).toBe('PUT');
    req.flush({ ok: true, data: { ...mockProducto, stock: 20 } });
  });

  it('delete hace DELETE y retorna producto eliminado', () => {
    service.delete(1).subscribe(p => expect(p.id).toBe(1));
    const req = http.expectOne('/api/productos/1');
    expect(req.request.method).toBe('DELETE');
    req.flush({ ok: true, data: mockProducto });
  });
});
