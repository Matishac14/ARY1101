import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { PedidosComponent } from './pedidos.component';
import { PedidosService } from '../../services/pedidos.service';
import { Pedido } from '../../models/technova.models';

const mockPedido: Pedido = { id: 1, producto_id: 1, cantidad: 2, estado: 'pendiente', producto_nombre: 'Notebook' };
const mockSvc = () => ({
  getAll:  jest.fn().mockReturnValue(of([mockPedido])),
  create:  jest.fn().mockReturnValue(of(mockPedido)),
  update:  jest.fn().mockReturnValue(of(mockPedido)),
  delete:  jest.fn().mockReturnValue(of(mockPedido)),
});

describe('PedidosComponent', () => {
  let svc: ReturnType<typeof mockSvc>;

  beforeEach(async () => {
    svc = mockSvc();
    await TestBed.configureTestingModule({
      imports: [PedidosComponent],
      providers: [{ provide: PedidosService, useValue: svc }],
    }).compileComponents();
  });

  it('carga pedidos al iniciar', fakeAsync(() => {
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick(); fixture.detectChanges();
    expect(fixture.componentInstance.pedidos).toHaveLength(1);
  }));

  it('muestra error cuando getAll falla', fakeAsync(() => {
    svc.getAll.mockReturnValue(throwError(() => new Error('DB error')));
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick(); fixture.detectChanges();
    expect(fixture.componentInstance.error).toBe('DB error');
  }));

  it('submit muestra error si faltan campos', () => {
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges();
    const comp = fixture.componentInstance;
    comp.form = { producto_id: 0, cantidad: 0 };
    comp.submit();
    expect(comp.formError).toBe('producto_id y cantidad son requeridos');
  });

  it('submit crea pedido nuevo', fakeAsync(() => {
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.form = { producto_id: 1, cantidad: 2, estado: 'pendiente' };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(svc.create).toHaveBeenCalled();
  }));

  it('submit actualiza pedido existente', fakeAsync(() => {
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.editId = 1;
    comp.form = { producto_id: 1, cantidad: 3, estado: 'enviado' };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(svc.update).toHaveBeenCalledWith(1, expect.any(Object));
  }));

  it('submit en update muestra error si falla', fakeAsync(() => {
    svc.update.mockReturnValue(throwError(() => new Error('Fallo')));
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.editId = 1;
    comp.form = { producto_id: 1, cantidad: 1, estado: 'pendiente' };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(comp.formError).toBe('Fallo');
  }));

  it('submit en create muestra error si falla', fakeAsync(() => {
    svc.create.mockReturnValue(throwError(() => new Error('Fallo create')));
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.form = { producto_id: 1, cantidad: 1, estado: 'pendiente' };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(comp.formError).toBe('Fallo create');
  }));

  it('edit rellena el formulario', () => {
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges();
    const comp = fixture.componentInstance;
    comp.edit(mockPedido);
    expect(comp.editId).toBe(1);
    expect(comp.showForm).toBe(true);
  });

  it('cancelEdit resetea el formulario', () => {
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges();
    const comp = fixture.componentInstance;
    comp.edit(mockPedido);
    comp.cancelEdit();
    expect(comp.editId).toBeNull();
    expect(comp.showForm).toBe(false);
  });

  it('remove cancela si el usuario no confirma', fakeAsync(() => {
    jest.spyOn(window, 'confirm').mockReturnValue(false);
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    fixture.componentInstance.remove(1);
    expect(svc.delete).not.toHaveBeenCalled();
  }));

  it('remove elimina el pedido y recarga', fakeAsync(() => {
    jest.spyOn(window, 'confirm').mockReturnValue(true);
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    fixture.componentInstance.remove(1);
    tick(); fixture.detectChanges();
    expect(svc.delete).toHaveBeenCalledWith(1);
  }));

  it('remove muestra error si delete falla', fakeAsync(() => {
    jest.spyOn(window, 'confirm').mockReturnValue(true);
    svc.delete.mockReturnValue(throwError(() => new Error('Fallo delete')));
    const fixture = TestBed.createComponent(PedidosComponent);
    fixture.detectChanges(); tick();
    fixture.componentInstance.remove(1);
    tick(); fixture.detectChanges();
    expect(fixture.componentInstance.error).toBe('Fallo delete');
  }));
});
