import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '',         redirectTo: 'dashboard', pathMatch: 'full' },
  { path: 'dashboard', loadComponent: () => import('./pages/dashboard/dashboard.component').then(m => m.DashboardComponent) },
  { path: 'productos', loadComponent: () => import('./pages/productos/productos.component').then(m => m.ProductosComponent) },
  { path: 'pedidos',   loadComponent: () => import('./pages/pedidos/pedidos.component').then(m => m.PedidosComponent) },
  { path: '**',        redirectTo: 'dashboard' },
];
