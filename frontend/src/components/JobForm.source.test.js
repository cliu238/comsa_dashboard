import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const jobFormSrc = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

describe('Source citation moved out of the job form (issue #69)', () => {
  it('no longer renders the sample-source citation', () => {
    expect(jobFormSrc).not.toContain('sample-source')
    expect(jobFormSrc).not.toContain('R package version 2.0. COMSA Mozambique data.')
  })

  it('still keeps the sample CSV download links', () => {
    expect(jobFormSrc).toContain('sample-links')
  })
})
