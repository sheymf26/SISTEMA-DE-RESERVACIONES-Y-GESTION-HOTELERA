import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-module-page',
  standalone: true,
  templateUrl: './module-page.component.html',
  styleUrl: './module-page.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ModulePageComponent {
  readonly title: string = inject(ActivatedRoute).snapshot.data['label'];
}
