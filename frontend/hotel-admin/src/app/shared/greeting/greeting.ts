export function greetingForHour(hour: number): string {
  if (hour >= 5 && hour < 12) {
    return 'Buenos días';
  }

  if (hour >= 12 && hour < 18) {
    return 'Buenas tardes';
  }

  return 'Buenas noches';
}
