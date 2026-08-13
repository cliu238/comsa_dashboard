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

import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirMM = dirname(fileURLToPath(import.meta.url))
const matrixSrc = readFileSync(resolve(__dirMM, 'MisclassificationMatrix.jsx'), 'utf-8')

describe('Misclassification small-multiples (issue #72)', () => {
  it('imports the shared formatAlgorithmName (no private copy)', () => {
    expect(matrixSrc).toContain("from '../utils/labels.js'")
    expect(matrixSrc).not.toContain('const algoMap = {')
  })

  it('renders integer-percent cells (round, not toFixed(3))', () => {
    expect(matrixSrc).toContain('Math.round(value * 100)')
    expect(matrixSrc).not.toContain('value.toFixed(3)')
  })

  it('lays out matrices as small-multiples', () => {
    expect(matrixSrc).toContain('matrix-small-multiples')
  })
})

// issue #116: this panel displays `Mmat_tomodel`, which vacalibration's own plot titles
// "Prior Mean of Misclassification Matrix — Used For Calibration". It is the identity
// matrix mixed with the CHAMPS estimate at the path-correction lambda, NOT the empirical
// misclassification rate. Measured on the shipped child/Ethiopia demo (lambda = 0.41,
// not even stalled): displayed diagonal mean 0.51 against the CHAMPS estimate's 0.33;
// at lambda = 0.99 it reads 0.99 against a real 0.135 for malaria. Calling that diagonal
// "sensitivity" tells a researcher the algorithm is far more accurate than it is.
describe('matrix is not labelled as empirical sensitivity (issue #116)', () => {
  it('does not claim the diagonal is sensitivity', () => {
    expect(matrixSrc).not.toMatch(/Diagonal = Sensitivity/)
    expect(matrixSrc).not.toMatch(/\[Sensitivity\]/)
    expect(matrixSrc).not.toMatch(/diagonal is sensitivity/)
  })

  it('uses vacalibration\'s own name for this matrix', () => {
    expect(matrixSrc).toContain('Used For Calibration')
  })

  it('states that it is a lambda mixture rather than the empirical rate', () => {
    expect(matrixSrc).toMatch(/mix|mixture/i)
    expect(matrixSrc).toContain('λ')
  })

  it('renders the lambda value in the description, not only in the stall note', () => {
    // Scoped to the description paragraph: asserting on the whole file passes even if
    // the disclosure is removed here, because the stall note contains the same guard.
    const desc = matrixSrc.split('className="matrix-description"')[1].split('</p>')[0]
    expect(desc).toContain("typeof lambda === 'number'")
    expect(desc).toContain('lambda.toFixed(2)')
  })

  it('warns when lambda is at the ceiling, where the matrix is ~identity', () => {
    expect(matrixSrc).toContain('ciUnreliable')
  })

  it('accepts lambda through the component contract', () => {
    expect(matrixSrc).toMatch(/MisclassificationMatrix\(\{[^}]*lambda/s)
  })
})
