import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { EMPTY_ROOM_FILTERS, RoomFilters } from './models/room';
import { RoomCardComponent } from './room-card/room-card.component';
import { RoomFiltersComponent } from './room-filters/room-filters.component';

@Component({
  selector: 'app-rooms',
  standalone: true,
  imports: [RoomCardComponent, RoomFiltersComponent],
  templateUrl: './rooms.component.html',
  styleUrl: './rooms.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RoomsComponent {
  readonly filters = signal<RoomFilters>(EMPTY_ROOM_FILTERS);
  // Posiciones de una vista de diseño; no representan registros de habitaciones.
  readonly previewSlots = [0, 1, 2];
}
