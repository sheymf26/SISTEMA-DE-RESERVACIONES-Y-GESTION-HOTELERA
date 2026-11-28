import { describe, expect, it } from 'vitest';
import { greetingForHour } from './greeting';

describe('Saludo según la hora local', () => {
  it.each([
    [0, 'Buenas noches'],
    [4, 'Buenas noches'],
    [5, 'Buenos días'],
    [11, 'Buenos días'],
    [12, 'Buenas tardes'],
    [17, 'Buenas tardes'],
    [18, 'Buenas noches'],
    [23, 'Buenas noches'],
  ])('a las %i corresponde %s', (hour, expected) => {
    expect(greetingForHour(hour)).toBe(expected);
  });
});
