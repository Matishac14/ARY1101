import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PedidosService } from '../../services/pedidos.service';
import { Pedido } from '../../models/technova.models';

const ESTADOS: Pedido['estado'][] = ['pendiente', 'procesado', 'enviado', 'cancelado'];

@Component({
  selector: 'app-pedidos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page">
      <div class="page-header">
        <h1 class="page-title">Pedidos</h1>
        <button class="btn btn-primary" (click)="showForm = !showForm">
          {{ showForm ? 'Cancelar' : '+ Nuevo Pedido' }}
        </button>
      </div>

      <form *ngIf="showForm" class="form-card" (ngSubmit)="submit()">
        <h3>{{ editId ? 'Editar Pedido' : 'Nuevo Pedido' }}</h3>
        <label>Producto ID <input [(ngModel)]="form.producto_id" name="producto_id" type="number" required /></label>
        <label>Cantidad <input [(ngModel)]="form.cantidad" name="cantidad" type="number" required /></label>
        <label>Estado
          <select [(ngModel)]="form.estado" name="estado">
            <option *ngFor="let e of estados" [value]="e">{{ e }}</option>
          </select>
        </label>
        <div class="form-actions">
          <button type="submit" class="btn btn-primary">{{ editId ? 'Guardar' : 'Crear' }}</button>
          <button type="button" class="btn btn-secondary" (click)="cancelEdit()">Cancelar</button>
        </div>
        <p class="form-error" *ngIf="formError">{{ formError }}</p>
      </form>

      <div *ngIf="loading" class="loading">Cargando…</div>
      <p class="error" *ngIf="error">{{ error }}</p>

      <table class="data-table" *ngIf="!loading && pedidos.length > 0">
        <thead>
          <tr><th>ID</th><th>Producto</th><th>Cantidad</th><th>Estado</th><th>Acciones</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let p of pedidos">
            <td>{{ p.id }}</td>
            <td>{{ p.producto_nombre || p.producto_id }}</td>
            <td>{{ p.cantidad }}</td>
            <td><span class="estado-badge estado-{{ p.estado }}">{{ p.estado }}</span></td>
            <td class="actions">
              <button class="btn btn-sm btn-secondary" (click)="edit(p)">Editar</button>
              <button class="btn btn-sm btn-danger" (click)="remove(p.id)">Eliminar</button>
            </td>
          </tr>
        </tbody>
      </table>

      <p *ngIf="!loading && pedidos.length === 0" class="empty">No hay pedidos registrados.</p>
    </div>
  `,
})
export class PedidosComponent implements OnInit {
  pedidos: Pedido[] = [];
  estados = ESTADOS;
  loading = true;
  error = '';
  showForm = false;
  editId: number | null = null;
  formError = '';
  form: Partial<Pedido> = { producto_id: 0, cantidad: 1, estado: 'pendiente' };

  constructor(private service: PedidosService) {}

  ngOnInit(): void { this.load(); }

  load(): void {
    this.loading = true;
    this.service.getAll().subscribe({
      next: (data) => { this.pedidos = data; this.loading = false; },
      error: (err)  => { this.error = err.message; this.loading = false; },
    });
  }

  edit(p: Pedido): void {
    this.editId = p.id;
    this.form = { producto_id: p.producto_id, cantidad: p.cantidad, estado: p.estado };
    this.showForm = true;
  }

  cancelEdit(): void {
    this.editId = null;
    this.form = { producto_id: 0, cantidad: 1, estado: 'pendiente' };
    this.showForm = false;
    this.formError = '';
  }

  submit(): void {
    this.formError = '';
    if (!this.form.producto_id || !this.form.cantidad) {
      this.formError = 'producto_id y cantidad son requeridos';
      return;
    }
    const payload = { producto_id: +this.form.producto_id!, cantidad: +this.form.cantidad!, estado: this.form.estado! };

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
    if (!confirm('¿Eliminar este pedido?')) return;
    this.service.delete(id).subscribe({
      next: () => this.load(),
      error: (err) => { this.error = err.message; },
    });
  }
}
