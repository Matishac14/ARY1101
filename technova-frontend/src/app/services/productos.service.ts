import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { ApiInfo, ApiResponse, Producto } from '../models/technova.models';

@Injectable({ providedIn: 'root' })
export class ProductosService {
  private readonly base = '/api/productos';

  constructor(private http: HttpClient) {}

  getInfo(): Observable<ApiInfo> {
    return this.http.get<ApiInfo>(`${this.base}/info`);
  }

  getAll(): Observable<Producto[]> {
    return this.http.get<ApiResponse<Producto[]>>(this.base).pipe(map(r => r.data));
  }

  getById(id: number): Observable<Producto> {
    return this.http.get<ApiResponse<Producto>>(`${this.base}/${id}`).pipe(map(r => r.data));
  }

  create(payload: Omit<Producto, 'id' | 'creado_en' | 'actualizado_en'>): Observable<Producto> {
    return this.http.post<ApiResponse<Producto>>(this.base, payload).pipe(map(r => r.data));
  }

  update(id: number, payload: Partial<Producto>): Observable<Producto> {
    return this.http.put<ApiResponse<Producto>>(`${this.base}/${id}`, payload).pipe(map(r => r.data));
  }

  delete(id: number): Observable<Producto> {
    return this.http.delete<ApiResponse<Producto>>(`${this.base}/${id}`).pipe(map(r => r.data));
  }
}
