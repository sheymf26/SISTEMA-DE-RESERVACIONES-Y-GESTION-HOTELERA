import { ChangeDetectionStrategy, Component, computed, inject, output } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { canAccessModule, NAVIGATION_GROUPS } from '../../core/navigation/module-catalog';
import { SESSION_GATEWAY } from '../../core/session/session-gateway';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-sidebar',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, IconComponent],
  templateUrl: './sidebar.component.html',
  styleUrl: './sidebar.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SidebarComponent {
  private readonly session = inject(SESSION_GATEWAY);
  readonly navigated = output<void>();
  readonly closeMenu = output<void>();
  readonly groups = computed(() => {
    const roles = this.session.user()?.roles ?? [];

    return NAVIGATION_GROUPS.map((group) => ({
      ...group,
      modules: group.modules.filter((module) => canAccessModule(module, roles)),
    })).filter((group) => group.modules.length > 0);
  });
}
