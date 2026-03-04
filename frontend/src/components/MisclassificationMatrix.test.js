import { describe, it, expect } from 'vitest'
import { getCellColor, isDiagonalCell } from '../utils/matrixUtils.js'

describe('getCellColor (white-to-red gradient)', () => {
  it('returns white for value 0', () => {
    expect(getCellColor(0)).toBe('rgb(255, 255, 255)')
  })

  it('returns deep red for value 1', () => {
    const color = getCellColor(1)
    const [, r, g, b] = color.match(/rgb\((\d+), (\d+), (\d+)\)/).map(Number)
    expect(r).toBeGreaterThan(150) // high red channel
    expect(g).toBeLessThan(50)     // low green
    expect(b).toBeLessThan(50)     // low blue
  })

  it('returns a reddish tone at midpoint (red stays 255, g/b decrease)', () => {
    const color = getCellColor(0.5)
    const [, r, g, b] = color.match(/rgb\((\d+), (\d+), (\d+)\)/).map(Number)
    expect(r).toBe(255)           // red channel stays maxed
    expect(g).toBeLessThan(255)   // green decreasing
    expect(b).toBeLessThan(255)   // blue decreasing
  })

  it('green and blue decrease monotonically as value increases', () => {
    const parse = (c) => c.match(/rgb\((\d+), (\d+), (\d+)\)/).slice(1).map(Number)
    const [, g1, b1] = parse(getCellColor(0.2))
    const [, g2, b2] = parse(getCellColor(0.5))
    const [, g3, b3] = parse(getCellColor(0.8))
    expect(g1).toBeGreaterThan(g2)
    expect(g2).toBeGreaterThan(g3)
    expect(b1).toBeGreaterThan(b2)
    expect(b2).toBeGreaterThan(b3)
  })

  it('never has red channel below green or blue', () => {
    for (const v of [0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
      const [, r, g, b] = getCellColor(v).match(/rgb\((\d+), (\d+), (\d+)\)/).map(Number)
      expect(r).toBeGreaterThanOrEqual(g)
      expect(r).toBeGreaterThanOrEqual(b)
    }
  })
})

describe('isDiagonalCell', () => {
  it('returns true when champs and va cause names match at given indices', () => {
    const champs = ['prematurity', 'pneumonia', 'other']
    const va = ['prematurity', 'pneumonia', 'other']
    expect(isDiagonalCell(0, 0, champs, va)).toBe(true)
    expect(isDiagonalCell(1, 1, champs, va)).toBe(true)
    expect(isDiagonalCell(2, 2, champs, va)).toBe(true)
  })

  it('returns false when causes at those indices differ', () => {
    const champs = ['prematurity', 'pneumonia', 'other']
    const va = ['prematurity', 'pneumonia', 'other']
    expect(isDiagonalCell(0, 1, champs, va)).toBe(false)
    expect(isDiagonalCell(1, 0, champs, va)).toBe(false)
  })

  it('matches by name, not index position (non-square matrix)', () => {
    const champs = ['prematurity', 'pneumonia']
    const va = ['pneumonia', 'prematurity', 'other']
    // champs[0]='prematurity' matches va[1]='prematurity'
    expect(isDiagonalCell(0, 1, champs, va)).toBe(true)
    // champs[0]='prematurity' != va[0]='pneumonia'
    expect(isDiagonalCell(0, 0, champs, va)).toBe(false)
    // champs[1]='pneumonia' matches va[0]='pneumonia'
    expect(isDiagonalCell(1, 0, champs, va)).toBe(true)
  })

  it('returns false when cause has no match in the other axis', () => {
    const champs = ['prematurity', 'malaria']
    const va = ['pneumonia', 'other']
    expect(isDiagonalCell(0, 0, champs, va)).toBe(false)
    expect(isDiagonalCell(0, 1, champs, va)).toBe(false)
  })
})
