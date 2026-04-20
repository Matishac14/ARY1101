import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { ProductosComponent } from './productos.component';
import { ProductosService } from '../../services/productos.service';
import { Producto } from '../../models/technova.models';

const mockProducto: Producto = { id: 1, nombre: 'Notebook', precio: 649990, stock: 10, categoria: 'Computadores' };
const mockSvc = () => ({
  getAll:  jest.fn().mockReturnValue(of([mockProducto])),
  create:  jest.fn().mockReturnValue(of(mockProducto)),
  update:  jest.fn().mockReturnValue(of(mockProducto)),
  delete:  jest.fn().mockReturnValue(of(mockProducto)),
});

describe('ProductosComponent', () => {
  let svc: ReturnType<typeof mockSvc>;

  beforeEach(async () => {
    svc = mockSvc();
    await TestBed.configureTestingModule({
      imports: [ProductosComponent],
      providers: [{ provide: ProductosService, useValue: svc }],
    }).compileComponents();
  });

  it('carga productos al iniciar', fakeAsync(() => {
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick(); fixture.detectChanges();
    expect(fixture.componentInstance.productos).toHaveLength(1);
    expect(fixture.componentInstance.loading).toBe(false);
  }));

  it('muestra error cuando getAll falla', fakeAsync(() => {
    svc.getAll.mockReturnValue(throwError(() => new Error('DB error')));
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick(); fixture.detectChanges();
    expect(fixture.componentInstance.error).toBe('DB error');
  }));

  it('submit muestra error si faltan campos', () => {
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges();
    const comp = fixture.componentInstance;
    comp.form = { nombre: '', precio: 0 };
    comp.submit();
    expect(comp.formError).toBe('Nombre y precio son requeridos');
  });

  it('submit crea producto nuevo', fakeAsync(() => {
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.form = { nombre: 'Mouse', precio: 9990, stock: 5, categoria: 'Periféricos' };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(svc.create).toHaveBeenCalled();
  }));

  it('submit actualiza producto existente', fakeAsync(() => {
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.editId = 1;
    comp.form = { nombre: 'Notebook Pro', precio: 799990, stock: 5, categoria: 'Computadores' };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(svc.update).toHaveBeenCalledWith(1, expect.any(Object));
  }));

  it('submit en update muestra error si falla', fakeAsync(() => {
    svc.update.mockReturnValue(throwError(() => new Error('Fallo update')));
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.editId = 1;
    comp.form = { nombre: 'X', precio: 1, stock: 0, categoria: null };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(comp.formError).toBe('Fallo update');
  }));

  it('submit en create muestra error si falla', fakeAsync(() => {
    svc.create.mockReturnValue(throwError(() => new Error('Fallo create')));
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    const comp = fixture.componentInstance;
    comp.form = { nombre: 'X', precio: 1, stock: 0, categoria: null };
    comp.submit();
    tick(); fixture.detectChanges();
    expect(comp.formError).toBe('Fallo create');
  }));

  it('edit rellena el formulario', () => {
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges();
    const comp = fixture.componentInstance;
    comp.edit(mockProducto);
    expect(comp.editId).toBe(1);
    expect(comp.form.nombre).toBe('Notebook');
    expect(comp.showForm).toBe(true);
  });

  it('cancelEdit resetea el formulario', () => {
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges();
    const comp = fixture.componentInstance;
    comp.edit(mockProducto);
    comp.cancelEdit();
    expect(comp.editId).toBeNull();
    expect(comp.showForm).toBe(false);
  });

  it('remove cancela si el usuario no confirma', fakeAsync(() => {
    jest.spyOn(window, 'confirm').mockReturnValue(false);
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    fixture.componentInstance.remove(1);
    expect(svc.delete).not.toHaveBeenCalled();
  }));

  it('remove elimina el producto y recarga', fakeAsync(() => {
    jest.spyOn(window, 'confirm').mockReturnValue(true);
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    fixture.componentInstance.remove(1);
    tick(); fixture.detectChanges();
    expect(svc.delete).toHaveBeenCalledWith(1);
  }));

  it('remove muestra error si delete falla', fakeAsync(() => {
    jest.spyOn(window, 'confirm').mockReturnValue(true);
    svc.delete.mockReturnValue(throwError(() => new Error('Fallo delete')));
    const fixture = TestBed.createComponent(ProductosComponent);
    fixture.detectChanges(); tick();
    fixture.componentInstance.remove(1);
    tick(); fixture.detectChanges();
    expect(fixture.componentInstance.error).toBe('Fallo delete');
  }));
});
