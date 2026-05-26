import { describe, it, expect } from 'vitest'
import {
  PACKAGE_LINKS, REFERENCES, AWARD, ORGS, CREDIT, SAMPLE_DATA_SOURCE,
  INVESTIGATORS, CONTRIBUTORS,
} from './links'

const isHttps = (u) => typeof u === 'string' && u.startsWith('https://')

describe('content/links data module', () => {
  it('has exactly 4 references, each with an https URL and a title', () => {
    expect(REFERENCES).toHaveLength(4)
    REFERENCES.forEach((r) => {
      expect(isHttps(r.url)).toBe(true)
      expect(r.title.length).toBeGreaterThan(0)
      expect(typeof r.year).toBe('number')
      expect(String(r.year).length).toBe(4)
    })
  })

  it('package links point to a vacalibration GitHub repo and the CRAN page', () => {
    expect(PACKAGE_LINKS.github).toMatch(/github\.com\/[^/]+\/vacalibration/)
    expect(PACKAGE_LINKS.github).toContain('sandy-pramanik/vacalibration')
    expect(PACKAGE_LINKS.cran).toBe('https://cran.r-project.org/package=vacalibration')
  })

  it('award and org links are https', () => {
    expect(isHttps(AWARD.url)).toBe(true)
    expect(isHttps(ORGS.dsai.url)).toBe(true)
    expect(isHttps(ORGS.biostat.url)).toBe(true)
    expect(isHttps(ORGS.intlHealth.url)).toBe(true)
  })

  it('credit line uses the issue #69 wording verbatim', () => {
    expect(CREDIT.prefix).toBe('Designed and maintained by ')
    expect(CREDIT.parts.map((p) => p.label)).toEqual([
      'DSAI', 'Dept of Biostat', 'Dept of International Health',
    ])
    expect(CREDIT.suffix).toBe(' at Johns Hopkins')
    CREDIT.parts.forEach((p) => expect(isHttps(p.url)).toBe(true))
  })

  it('sample-data source has citation text and a link', () => {
    expect(SAMPLE_DATA_SOURCE.text).toMatch(/Pramanik S, Wilson E/)
    expect(isHttps(SAMPLE_DATA_SOURCE.url)).toBe(true)
    expect(SAMPLE_DATA_SOURCE.url).toContain('sandy-pramanik/vacalibration')
  })

  it('exports investigator and contributor arrays', () => {
    expect(Array.isArray(INVESTIGATORS)).toBe(true)
    expect(Array.isArray(CONTRIBUTORS)).toBe(true)
  })
})
