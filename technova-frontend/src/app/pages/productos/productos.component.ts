import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ProductosService } from '../../services/productos.service';
import { Producto } from '../../models/technova.models';

@Component({
  selector: 'app-productos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page">
      <div class="page-header">
        <h1 class="page-title">Catálogo de Productos</h1>
        <button class="btn btn-primary" (click)="showForm = !showForm">
          {{ showForm ? 'Cancelar' : '+ Nuevo Producto' }}
        </button>
      </div>

      <form *ngIf="showForm" class="form-card" (ngSubmit)="submit()">
        <h3>{{ editId ? 'Editar Producto' : 'Nuevo Producto' }}</h3>
        <label>Nombre <input [(ngModel)]="form.nombre" name="nombre" required /></label>
        <label>Precio <input [(ngModel)]="form.precio" name="precio" type="number" required /></label>
        <label>Stock <input [(ngModel)]="form.stock" name="stock" type="number" /></label>
        <label>Categoría <input [(ngModel)]="form.categoria" name="categoria" /></label>
        <div class="form-actions">
          <button type="submit" class="btn btn-primary">{{ editId ? 'Guardar' : 'Crear' }}</button>
          <button type="button" class="btn btn-secondary" (click)="cancelEdit()">Cancelar</button>
        </div>
        <p class="form-error" *ngIf="formError">{{ formError }}</p>
      </form>

      <div *ngIf="loading" class="loading">Cargando…</div>
      <p class="error" *ngIf="error">{{ error }}</p>

      <table class="data-table" *ngIf="!loading && productos.length > 0">
        <thead>
          <tr><th>ID</th><th>Nombre</th><th>Precio</th><th>Stock</th><th>Categoría</th><th>Acciones</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let p of productos">
            <td>{{ p.id }}</td>
            <td>{{ p.nombre }}</td>
            <td>{{ p.precio | currency:'CLP':'symbol':'1.0-0' }}</td>
            <td>{{ p.stock }}</td>
            <td>{{ p.categoria || '—' }}</td>
            <td class="actions">
              <button class="btn btn-sm btn-secondary" (click)="edit(p)">Editar</button>
              <button class="btn btn-sm btn-danger" (click)="remove(p.id)">Eliminar</button>
            </td>
          </tr>
        </tbody>
      </table>

      <p *ngIf="!loading && productos.length === 0" class="empty">No hay productos registrados.</p>
    </div>
  `,
})
export class ProductosComponent implements OnInit {
  productos: Producto[] = [];
  loading = true;
  error = '';
  showForm = false;
  editId: number | null = null;
  formError = '';
  form: Partial<Producto> = { nombre: '', precio: 0, stock: 0, categoria: '' };

  constructor(private service: ProductosService) {}

  ngOnInit(): void { this.load(); }

  load(): void {
    this.loading = true;
    this.service.getAll().subscribe({
      next: (data) => { this.productos = data; this.loading = false; },
      error: (err)  => { this.error = err.message; this.loading = false; },
    });
  }

  edit(p: Producto): void {
    this.editId = p.id;
    this.form = { nombre: p.nombre, precio: p.precio, stock: p.stock, categoria: p.categoria };
    this.showForm = true;
  }

  cancelEdit(): void {
    this.editId = null;
    this.form = { nombre: '', precio: 0, stock: 0, categoria: '' };
    this.showForm = false;
    this.formError = '';
  }

  submit(): void {
    this.formError = '';
    if (!this.form.nombre || this.form.precio === undefined) {
      this.formError = 'Nombre y precio son requeridos';
      return;
    }
    const payload = { nombre: this.form.nombre!, precio: +this.form.precio!, stock: +(this.form.stock ?? 0), categoria: this.form.categoria ?? null };

    if (this.editId) {
      this.service.update(this.editId, payload).subscribe({
        next: () => { this.cancelEdit(); this.load(); },
        error: (err) => { this.formError = err.message; },
      });
    } else {
      this.service.create(payload).subscribe({
        next: () => { this.cancelEdit(); this.load(); },
        error: (err) => { this.formError = err.message; },
      });
    }
  }

  remove(id: number): void {
    if (!confirm('¿Eliminar este producto?')) return;
    this.service.delete(id).subscribe({
      next: () => this.load(),
      error: (err) => { this.error = err.message; },
    });
  }
}
