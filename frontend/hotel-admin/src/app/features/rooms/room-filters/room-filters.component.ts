import { ChangeDetectionStrategy, Component, model } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  BuildingCode,
  EMPTY_ROOM_FILTERS,
  FloorNumber,
  RoomFilters,
  ROOM_STATUS_LABELS,
  ROOM_TYPES,
  RoomStatus,
} from '../models/room';

@Component({
  selector: 'app-room-filters',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './room-filters.component.html',
  styleUrl: './room-filters.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RoomFiltersComponent {
  readonly filters = model<RoomFilters>(EMPTY_ROOM_FILTERS);
  readonly buildings: readonly BuildingCode[] = ['A', 'B', 'C', 'D'];
  readonly floors: readonly FloorNumber[] = [1, 2, 3, 4, 5, 6];
  readonly types = ROOM_TYPES;
  readonly statuses = Object.entries(ROOM_STATUS_LABELS) as [RoomStatus, string][];

  setFilter<Key extends keyof RoomFilters>(key: Key, value: RoomFilters[Key]): void {
    this.filters.update((current) => ({ ...current, [key]: value }));
  }
}
