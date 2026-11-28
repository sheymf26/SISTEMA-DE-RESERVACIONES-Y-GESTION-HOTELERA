// Valores del catálogo y CK_Habitacion_Estado de HotelDB_Proyecto.sql.
// Estos modelos de presentación no definen ni sustituyen contratos HTTP.
export type RoomStatus = 'DISPONIBLE' | 'OCUPADA' | 'LIMPIEZA' | 'MANTENIMIENTO' | 'FUERA_SERVICIO';
export type RoomType = 'Sencilla' | 'Doble' | 'Familiar' | 'Suite';
export type BuildingCode = 'A' | 'B' | 'C' | 'D';
export type FloorNumber = 1 | 2 | 3 | 4 | 5 | 6;

export interface RoomCardData {
  readonly id: string;
  readonly code: string;
  readonly typeName: string;
  readonly buildingName: string;
  readonly floor: number;
  readonly guestCapacity: number;
  readonly pricePerNight: number | null;
  readonly currency: string;
  readonly status: RoomStatus;
  readonly photoUrl?: string | null;
}

export interface RoomFilters {
  readonly building: BuildingCode | '';
  readonly floor: FloorNumber | '';
  readonly type: RoomType | '';
  readonly status: RoomStatus | '';
}

export const EMPTY_ROOM_FILTERS: RoomFilters = {
  building: '',
  floor: '',
  type: '',
  status: '',
};

export const ROOM_TYPES: readonly RoomType[] = ['Sencilla', 'Doble', 'Familiar', 'Suite'];

export const ROOM_STATUS_LABELS: Readonly<Record<RoomStatus, string>> = {
  DISPONIBLE: 'Disponible',
  OCUPADA: 'Ocupada',
  LIMPIEZA: 'Limpieza',
  MANTENIMIENTO: 'Mantenimiento',
  FUERA_SERVICIO: 'Fuera de servicio',
};
