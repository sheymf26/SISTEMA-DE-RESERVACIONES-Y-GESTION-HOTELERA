import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { SESSION_GATEWAY } from '../../core/session/session-gateway';
import { greetingForHour } from './greeting';

@Component({
  selector: 'app-greeting',
  standalone: true,
  templateUrl: './greeting.component.html',
  styleUrl: './greeting.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class GreetingComponent {
  readonly session = inject(SESSION_GATEWAY);
  readonly greeting = signal(greetingForHour(new Date().getHours()));

  constructor() {
    const timer = setInterval(() => {
      this.greeting.set(greetingForHour(new Date().getHours()));
    }, 1000);

    inject(DestroyRef).onDestroy(() => clearInterval(timer));
  }
}
