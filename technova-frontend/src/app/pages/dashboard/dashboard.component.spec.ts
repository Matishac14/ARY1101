import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { of, throwError } from 'rxjs';
import { DashboardComponent } from './dashboard.component';
import { ProductosService } from '../../services/productos.service';
import { PedidosService } from '../../services/pedidos.service';
import { ApiInfo } from '../../models/technova.models';

const mockInfo: ApiInfo = { servicio: 'api-productos', version: '1.0.0', alumno_nombre: 'Juan Perez', alumno_rut: '12345678-9', alumno_seccion: 'ARY1101', db_connected: true };
const mockInfoPedidos: ApiInfo = { ...mockInfo, servicio: 'api-pedidos' };

describe('DashboardComponent', () => {
  let productosSvc: jest.Mocked<ProductosService>;
  let pedidosSvc: jest.Mocked<PedidosService>;

  beforeEach(async () => {
    productosSvc = { getInfo: jest.fn(), getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn() } as any;
    pedidosSvc   = { getInfo: jest.fn(), getAll: jest.fn(), getById: jest.fn(), create: jest.fn(), update: jest.fn(), delete: jest.fn() } as any;

    await TestBed.configureTestingModule({
      imports: [DashboardComponent, HttpClientTestingModule],
      providers: [
        { provide: ProductosService, useValue: productosSvc },
        { provide: PedidosService,   useValue: pedidosSvc },
      ],
    }).compileComponents();
  });

  it('muestra información de ambos servicios', fakeAsync(() => {
    productosSvc.getInfo.mockReturnValue(of(mockInfo));
    pedidosSvc.getInfo.mockReturnValue(of(mockInfoPedidos));

    const fixture = TestBed.createComponent(DashboardComponent);
    fixture.detectChanges();
    tick();
    fixture.detectChanges();

    expect(fixture.componentInstance.infos).toHaveLength(2);
    expect(fixture.componentInstance.loading).toBe(false);
  }));

  it('muestra error cuando los servicios fallan', fakeAsync(() => {
    productosSvc.getInfo.mockReturnValue(throwError(() => new Error('timeout')));
    pedidosSvc.getInfo.mockReturnValue(throwError(() => new Error('timeout')));

    const fixture = TestBed.createComponent(DashboardComponent);
    fixture.detectChanges();
    tick();
    fixture.detectChanges();

    expect(fixture.componentInstance.error).toContain('No se pudo conectar');
    expect(fixture.componentInstance.loading).toBe(false);
  }));

  it('inicia en estado loading', () => {
    productosSvc.getInfo.mockReturnValue(of(mockInfo));
    pedidosSvc.getInfo.mockReturnValue(of(mockInfoPedidos));

    const fixture = TestBed.createComponent(DashboardComponent);
    expect(fixture.componentInstance.loading).toBe(true);
  });
});
