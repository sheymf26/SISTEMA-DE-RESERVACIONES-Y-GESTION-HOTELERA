import { ChangeDetectionStrategy, Component, computed, input, signal } from '@angular/core';
import { IonAvatar } from '@ionic/angular';

@Component({
  selector: 'app-user-avatar',
  standalone: true,
  imports: [IonAvatar],
  templateUrl: './user-avatar.component.html',
  styleUrl: './user-avatar.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserAvatarComponent {
  readonly userId = input.required<string>();
  readonly name = input.required<string>();
  readonly photoUrl = input<string | null | undefined>(null);
  private readonly failedPhotoUrl = signal<string | null>(null);
  readonly initials = computed(() => {
    return this.name().trim().split(/\s+/).filter(Boolean).slice(0, 2)
      .map((part) => Array.from(part)[0]).join('').toLocaleUpperCase('es') || '?';
  });
  readonly visiblePhotoUrl = computed(() => {
    const url = this.photoUrl()?.trim();
    return url && url !== this.failedPhotoUrl() ? url : null;
  });

  onPhotoError(): void {
    this.failedPhotoUrl.set(this.photoUrl()?.trim() ?? null);
  }
}
