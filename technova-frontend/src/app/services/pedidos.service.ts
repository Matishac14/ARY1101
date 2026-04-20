import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { ApiInfo, ApiResponse, Pedido } from '../models/technova.models';

@Injectable({ providedIn: 'root' })
export class PedidosService {
  private readonly base = '/api/pedidos';

  constructor(private http: HttpClient) {}

  getInfo(): Observable<ApiInfo> {
    return this.http.get<ApiInfo>(`${this.base}/info`);
  }

  getAll(): Observable<Pedido[]> {
    return this.http.get<ApiResponse<Pedido[]>>(this.base).pipe(map(r => r.data));
  }

  getById(id: number): Observable<Pedido> {
    return this.http.get<ApiResponse<Pedido>>(`${this.base}/${id}`).pipe(map(r => r.data));
  }

  create(payload: Omit<Pedido, 'id' | 'creado_en' | 'actualizado_en' | 'producto_nombre'>): Observable<Pedido> {
    return this.http.post<ApiResponse<Pedido>>(this.base, payload).pipe(map(r => r.data));
  }

  update(id: number, payload: Partial<Pedido>): Observable<Pedido> {
    return this.http.put<ApiResponse<Pedido>>(`${this.base}/${id}`, payload).pipe(map(r => r.data));
  }

  delete(id: number): Observable<Pedido> {
    return this.http.delete<ApiResponse<Pedido>>(`${this.base}/${id}`).pipe(map(r => r.data));
  }
}
