import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const src = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

describe('Age group label (issue #68)', () => {
  it('uses "Children (1-59 months)"', () => {
    expect(src).toContain('Children (1-59 months)')
    expect(src).not.toContain("label: 'Child (1-59 months)'")
  })
})

describe('Country dropdown (issue #68)', () => {
  it('lists the supported countries alphabetically with an "Other" option', () => {
    expect(src).toContain("{ value: 'other', label: 'Other' }")
    expect(src).not.toContain('All the countries')
    const order = ['Bangladesh', 'Ethiopia', 'Kenya', 'Mali', 'Mozambique', 'Sierra Leone', 'South Africa']
      .map((c) => src.indexOf(`value: '${c}', label: '${c}'`))
    order.forEach((p) => expect(p).toBeGreaterThan(-1))
    for (let i = 1; i < order.length; i++) expect(order[i]).toBeGreaterThan(order[i - 1])
  })
})

describe('CCVA algorithm label (issue #68)', () => {
  it('labels the algorithm field with the CCVA full name', () => {
    expect(src).toContain('Computer-Coded Verbal Autopsy (CCVA) Algorithm')
  })
})

describe('MCMC section (issue #68)', () => {
  it('renames the toggle to "MCMC Specifics"', () => {
    expect(src).toContain('MCMC Specifics')
    expect(src).not.toContain('Advanced MCMC Settings')
  })
  it('uses the new three-sentence MCMC hint', () => {
    expect(src).toContain('Higher iteration improves accuracy but requires more time.')
    expect(src).toContain('Burn-in discards early samples to warm up MCMC chain.')
    expect(src).toContain('Thinning reduces dependency between subsequent MCMC samples.')
  })
})

describe('Uncertainty checkbox (issue #68)', () => {
  it('uses a checkbox bound to calibModelType, not a Yes/No dropdown', () => {
    expect(src).toContain("checked={calibModelType === 'Mmatprior'}")
    expect(src).toContain("e.target.checked ? 'Mmatprior' : 'Mmatfixed'")
    expect(src).not.toContain("'Yes (Informative Prior)'")
    expect(src).not.toContain("'No (Fixed misclassification matrix)'")
  })
  it('uses the new label and hint with the CCVA matrices link', () => {
    // #73 item #8: heading "Uncertainty in CCVA misclassification" + "Propagate" checkbox.
    expect(src).toContain('Uncertainty in CCVA misclassification')
    expect(src).toContain('Controls whether to propagate uncertainty in')
    expect(src).toContain('https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices')
    expect(src).not.toContain('Controls how uncertainty in misclassification estimates is handled')
    expect(src).not.toContain('Propagate uncertainty in misclassification matrix')
  })
})
