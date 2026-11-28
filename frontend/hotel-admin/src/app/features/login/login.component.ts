import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { SESSION_GATEWAY } from '../../core/session/session-gateway';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, IconComponent, RouterLink],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LoginComponent {
  private readonly session = inject(SESSION_GATEWAY);
  private readonly router = inject(Router);
  readonly showPassword = signal(false);
  readonly submitting = signal(false);
  readonly error = signal('');
  username = '';
  password = '';

  togglePassword(): void {
    this.showPassword.update((visible) => !visible);
  }

  async signIn(): Promise<void> {
    if (this.submitting()) {
      return;
    }

    this.error.set('');
    this.submitting.set(true);

    try {
      const accepted = await this.session.signIn(this.username, this.password);
      this.password = '';

      if (accepted) {
        await this.router.navigate(['/dashboard']);
      } else {
        this.error.set('Usa jefe, administrador o cocinero y una contraseña de prueba.');
      }
    } finally {
      this.submitting.set(false);
    }
  }
}
