import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { SESSION_GATEWAY } from '../../core/session/session-gateway';
import { UserAvatarComponent } from '../../shared/user-avatar/user-avatar.component';
import { GreetingComponent } from '../../shared/greeting/greeting.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [GreetingComponent, UserAvatarComponent],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent {
  readonly session = inject(SESSION_GATEWAY);
  readonly actions = ['Ver ingresos', 'Ver nómina', 'Ver reportes', 'Solicitudes de aprobación'];
}
