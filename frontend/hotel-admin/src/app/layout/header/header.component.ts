import { ChangeDetectionStrategy, Component, inject, input, output } from '@angular/core';
import { SESSION_GATEWAY } from '../../core/session/session-gateway';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [IconComponent],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class HeaderComponent {
  readonly session = inject(SESSION_GATEWAY);
  readonly section = input.required<string>();
  readonly menuOpen = input(false);
  readonly toggleMenu = output<void>();
  readonly logout = output<void>();
}
