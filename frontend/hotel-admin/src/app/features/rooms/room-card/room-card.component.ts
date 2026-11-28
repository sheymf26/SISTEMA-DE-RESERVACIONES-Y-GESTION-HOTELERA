import { ChangeDetectionStrategy, Component, computed, input, signal } from '@angular/core';
import { IonButton } from '@ionic/angular';
import { IconComponent } from '../../../shared/icon/icon.component';
import { RoomCardData, ROOM_STATUS_LABELS } from '../models/room';

@Component({
  selector: 'app-room-card',
  standalone: true,
  imports: [IonButton, IconComponent],
  templateUrl: './room-card.component.html',
  styleUrl: './room-card.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RoomCardComponent {
  readonly room = input<RoomCardData | null>(null);
  private readonly failedPhotoUrl = signal<string | null>(null);
  readonly statusLabels = ROOM_STATUS_LABELS;
  readonly photoUrl = computed(() => {
    const url = this.room()?.photoUrl?.trim();
    return url && url !== this.failedPhotoUrl() ? url : null;
  });
  readonly priceLabel = computed(() => {
    const room = this.room();

    if (!room || room.pricePerNight === null) {
      return null;
    }

    return new Intl.NumberFormat('es-CR', {
      style: 'currency',
      currency: room.currency,
      maximumFractionDigits: 2,
    }).format(room.pricePerNight);
  });

  onPhotoError(): void {
    this.failedPhotoUrl.set(this.room()?.photoUrl?.trim() ?? null);
  }
}
