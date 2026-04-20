export interface Producto {
  id: number;
  nombre: string;
  precio: number;
  stock: number;
  categoria: string | null;
  creado_en?: string;
  actualizado_en?: string;
}

export interface Pedido {
  id: number;
  producto_id: number;
  cantidad: number;
  estado: 'pendiente' | 'procesado' | 'enviado' | 'cancelado';
  producto_nombre?: string;
  creado_en?: string;
  actualizado_en?: string;
}

export interface ApiInfo {
  servicio: string;
  version: string;
  alumno_nombre: string;
  alumno_rut: string;
  alumno_seccion: string;
  db_connected: boolean;
  estados_validos?: string[];
}

export interface ApiResponse<T> {
  ok: boolean;
  data: T;
  error?: string;
}
