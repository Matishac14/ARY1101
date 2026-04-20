import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { forkJoin } from 'rxjs';
import { ProductosService } from '../../services/productos.service';
import { PedidosService } from '../../services/pedidos.service';
import { ApiInfo } from '../../models/technova.models';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="page">
      <h1 class="page-title">Dashboard</h1>
      <p class="page-sub">Estado de los servicios desplegados en AWS</p>

      <div class="info-grid" *ngIf="!loading; else loader">
        <div class="info-card" *ngFor="let info of infos">
          <div class="info-header">
            <span class="info-icon">{{ info.servicio === 'api-productos' ? '📦' : '🛒' }}</span>
            <span class="info-name">{{ info.servicio }}</span>
            <span class="badge" [class.badge-ok]="info.db_connected" [class.badge-err]="!info.db_connected">
              {{ info.db_connected ? 'DB conectada' : 'DB sin conexión' }}
            </span>
          </div>
          <dl class="info-dl">
            <dt>Alumno</dt><dd>{{ info.alumno_nombre }}</dd>
            <dt>RUT</dt><dd>{{ info.alumno_rut }}</dd>
            <dt>Sección</dt><dd>{{ info.alumno_seccion }}</dd>
            <dt>Versión</dt><dd>{{ info.version }}</dd>
          </dl>
        </div>
      </div>

      <ng-template #loader>
        <p class="loading">Cargando información…</p>
      </ng-template>

      <p class="error" *ngIf="error">{{ error }}</p>
    </div>
  `,
})
export class DashboardComponent implements OnInit {
  infos: ApiInfo[] = [];
  loading = true;
  error = '';

  constructor(
    private productosService: ProductosService,
    private pedidosService: PedidosService,
  ) {}

  ngOnInit(): void {
    forkJoin({
      productos: this.productosService.getInfo(),
      pedidos:   this.pedidosService.getInfo(),
    }).subscribe({
      next: ({ productos, pedidos }) => {
        this.infos = [productos, pedidos];
        this.loading = false;
      },
      error: (err) => {
        this.error = 'No se pudo conectar con los servicios: ' + err.message;
        this.loading = false;
      },
    });
  }
}
