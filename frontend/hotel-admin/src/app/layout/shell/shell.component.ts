import { ChangeDetectionStrategy, Component, DestroyRef, HostListener, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterOutlet } from '@angular/router';
import { filter, map } from 'rxjs';
import { SESSION_GATEWAY } from '../../core/session/session-gateway';
import { HeaderComponent } from '../header/header.component';
import { SidebarComponent } from '../sidebar/sidebar.component';

@Component({
  selector: 'app-shell',
  standalone: true,
  imports: [HeaderComponent, SidebarComponent, RouterOutlet],
  templateUrl: './shell.component.html',
  styleUrl: './shell.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ShellComponent {
  private readonly router = inject(Router);
  private readonly session = inject(SESSION_GATEWAY);
  private readonly media = window.matchMedia('(max-width: 1100px)');
  readonly compact = signal(this.media.matches);
  readonly menuOpen = signal(false);
  readonly section = toSignal(
    this.router.events.pipe(
      filter((event) => event instanceof NavigationEnd),
      map(() => this.currentSection()),
    ),
    { initialValue: this.currentSection() },
  );

  constructor() {
    const destroyRef = inject(DestroyRef);
    const onResize = (): void => {
      this.compact.set(this.media.matches);
      this.menuOpen.set(false);
    };

    this.media.addEventListener('change', onResize);
    destroyRef.onDestroy(() => this.media.removeEventListener('change', onResize));

    this.router.events.pipe(
      filter((event) => event instanceof NavigationEnd),
      takeUntilDestroyed(),
    ).subscribe(() => {
      this.menuOpen.set(false);
      document.getElementById('main-content')?.focus();
    });
  }

  @HostListener('document:keydown.escape')
  closeMenu(): void {
    if (this.menuOpen()) {
      this.menuOpen.set(false);
      document.querySelector<HTMLButtonElement>('.menu-button')?.focus();
    }
  }

  openMenu(): void {
    this.menuOpen.set(true);
    setTimeout(() => document.querySelector<HTMLButtonElement>('.close-button')?.focus());
  }

  async signOut(): Promise<void> {
    this.session.signOut();
    await this.router.navigate(['/login']);
  }

  private currentSection(): string {
    let route = this.router.routerState.snapshot.root;

    while (route.firstChild) {
      route = route.firstChild;
    }

    const label: unknown = route.data['label'];
    return typeof label === 'string' ? label : 'Dashboard';
  }
}
