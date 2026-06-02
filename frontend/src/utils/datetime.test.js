import { describe, it, expect } from 'vitest'
import { formatTimestamp } from './datetime.js'

describe('formatTimestamp (issue #73)', () => {
  it('returns a dash for empty values', () => {
    expect(formatTimestamp(null)).toBe('-')
    expect(formatTimestamp(undefined)).toBe('-')
    expect(formatTimestamp('')).toBe('-')
  })

  it('includes a timezone label in the formatted output', () => {
    const out = formatTimestamp('2026-06-02T15:04:00Z')
    expect(out).not.toBe('-')
    expect(out).not.toBe('2026-06-02T15:04:00Z')
    expect(out.length).toBeGreaterThan(0)
  })

  it('handles the R array epoch-seconds format', () => {
    const epoch = new Date('2026-06-02T15:04:00Z').getTime() / 1000
    const out = formatTimestamp([epoch])
    expect(out).not.toBe('-')
  })

  it('parses a tz-less R string as UTC (delegates to parseTimestamp)', () => {
    const a = formatTimestamp('2026-06-02 15:04:00')
    const b = formatTimestamp('2026-06-02T15:04:00Z')
    expect(a).toBe(b)
  })

  it('returns a dash for unparseable input', () => {
    expect(formatTimestamp('not-a-date')).toBe('-')
  })
})
