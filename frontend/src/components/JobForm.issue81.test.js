import { describe, it, expect } from 'vitest'
import { readFileSync, existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const src = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')
const publicDir = resolve(__dir, '../../public')

describe('Child (1-59 months) sample CSV links (issue #81)', () => {
  it('offers child sample downloads for all three algorithms', () => {
    expect(src).toContain('sample_eava_child.csv')
    expect(src).toContain('sample_insilicova_child.csv')
    expect(src).toContain('sample_interva_child.csv')
  })

  it('labels the new sample line for the 1-59 months age group', () => {
    expect(src).toContain('1-59 months')
  })

  it('orders the child sample links EAVA, InSilicoVA, InterVA', () => {
    const eava = src.indexOf('sample_eava_child.csv')
    const insilico = src.indexOf('sample_insilicova_child.csv')
    const interva = src.indexOf('sample_interva_child.csv')
    expect(eava).toBeGreaterThan(-1)
    expect(eava).toBeLessThan(insilico)
    expect(insilico).toBeLessThan(interva)
  })

  it('places the child line below the neonate line', () => {
    expect(src.indexOf('sample_eava_neonate.csv')).toBeLessThan(src.indexOf('sample_eava_child.csv'))
  })

  it('the referenced child sample CSV files actually exist in public/', () => {
    expect(existsSync(resolve(publicDir, 'sample_eava_child.csv'))).toBe(true)
    expect(existsSync(resolve(publicDir, 'sample_insilicova_child.csv'))).toBe(true)
    expect(existsSync(resolve(publicDir, 'sample_interva_child.csv'))).toBe(true)
  })
})
