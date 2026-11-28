import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';


@Component({
  selector: 'app-icon',
  standalone: true,
  imports: [],
  templateUrl: './icon.component.html',
  styleUrl: './icon.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class IconComponent {
  readonly name = input.required<string>();
  readonly path = computed(() => ICON_PATHS[this.name()] ?? ICON_PATHS['home']);
}

const ICON_PATHS: Readonly<Record<string, string>> = {
  "home": "M3 10 12 3l9 7M5 9v12h5v-7h4v7h5V9",
  "user": "M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0M4 21v-2a8 8 0 0 1 16 0v2",
  "users": "M15 7a3 3 0 1 1-6 0 3 3 0 0 1 6 0M5 21v-2a7 7 0 0 1 14 0v2M18 4a3 3 0 0 1 0 6M21 21v-3a6 6 0 0 0-3-5",
  "bell": "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4",
  "bed": "M3 19V7m18 12V9M3 15h18M3 9h18M7 9V5h10v4M3 19v2m18-2v2",
  "building": "M5 21V3h14v18M3 21h18M9 7h1m4 0h1M9 11h1m4 0h1M10 21v-6h4v6",
  "calendar": "M4 5h16v16H4zM8 3v4m8-4v4M4 10h16M8 14h2m4 0h2m-8 3h2",
  "desk": "M3 12h18v9H3zM7 8h10M12 5v3M5 16h14",
  "arrows": "M3 7h17m-4-4 4 4-4 4M21 17H4m4-4-4 4 4 4",
  "utensils": "M4 3v6a3 3 0 0 0 6 0V3M7 3v18M20 21V3c-5 2-5 10 0 10",
  "chef": "M7 13a5 5 0 0 1-2-9 5 5 0 0 1 7-1 5 5 0 0 1 7 1 5 5 0 0 1-2 9v8H7zM7 17h10",
  "glass": "M4 3h16l-8 10zM12 13v8m-4 0h8",
  "tray": "M3 17h18M5 14a7 7 0 0 1 14 0M12 5V3m-3 18h6",
  "car": "M3 17V9l3-5h12l3 5v8H3zM3 10h18M6 14h1m10 0h1M5 17v3m14-3v3",
  "sparkles": "m12 3 2 6 6 3-6 2-2 7-2-7-6-2 6-3zM3 3v4M1 5h4",
  "tool": "M14 6a6 6 0 0 0-7 8l-5 5 3 3 5-5a6 6 0 0 0 8-7l-4 3-3-3z",
  "wallet": "M3 5h16v15H3zM3 5l13-3v3m0 6h5v5h-5z",
  "receipt": "M5 3v18l3-2 4 2 4-2 3 2V3H5zM9 7h6m-6 4h6m-6 4h3",
  "chart": "M4 3v18h17M8 16v-5m5 5V7m5 9v-7",
  "shield": "M12 3 3 7v6c0 5 9 9 9 9s9-4 9-9V7zM8 12l3 3 5-6",
  "check": "M4 12l5 5L20 5",
  "settings": "M9 3h6l1 3 3 1 2 5-2 5-3 1-1 3H9l-1-3-3-1-2-5 2-5 3-1zM15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0",
  "menu": "M4 6h16M4 12h16M4 18h16",
  "close": "m6 6 12 12M6 18 18 6",
  "logout": "M9 3H4v18h5M9 12h12m-5-5 5 5-5 5",
  "eye": "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0",
  "eye-off": "m3 3 18 18M9 5c7-2 13 7 13 7a19 19 0 0 1-4 4M6 6a20 20 0 0 0-4 6s7 11 15 5",
  "arrow": "M4 12h16m-6-6 6 6-6 6"
};
