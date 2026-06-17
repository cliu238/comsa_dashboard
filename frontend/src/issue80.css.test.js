import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const css = readFileSync(resolve(__dir, 'App.css'), 'utf-8')

// Issue #80 part 2: the consolidated CSMF table overlapped for the 1-59m (child)
// age group because the base .csmf-table forces table-layout:fixed with 40%/20%
// column widths — fine for ~3 columns, broken for the 11 columns child produces.
describe('Consolidated CSMF table column layout (issue #80)', () => {
  it('overrides the consolidated table to auto layout so columns size to content', () => {
    expect(css).toMatch(/\.csmf-table\.consolidated\s*\{[^}]*table-layout:\s*auto/)
  })

  it('resets the base fixed 40%/20% column widths to auto for the consolidated table', () => {
    expect(css).toMatch(/\.csmf-table\.consolidated th:first-child[\s\S]{0,120}width:\s*auto/)
  })

  it('allows long cause headers to wrap instead of overlapping', () => {
    expect(css).toMatch(/\.csmf-table\.consolidated th,[\s\S]{0,160}overflow-wrap:\s*break-word/)
  })
})
