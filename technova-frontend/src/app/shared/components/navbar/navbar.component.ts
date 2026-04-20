import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [RouterLink, RouterLinkActive],
  template: `
    <nav class="navbar">
      <div class="navbar-brand">
        <span class="brand-logo">⚡</span>
        <span class="brand-name">TechNova Solutions</span>
      </div>
      <ul class="navbar-links">
        <li><a routerLink="/dashboard" routerLinkActive="active">Dashboard</a></li>
        <li><a routerLink="/productos" routerLinkActive="active">Productos</a></li>
        <li><a routerLink="/pedidos" routerLinkActive="active">Pedidos</a></li>
      </ul>
    </nav>
  `,
})
export class NavbarComponent {}
