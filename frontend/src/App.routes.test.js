import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const appSrc = readFileSync(resolve(__dir, 'App.jsx'), 'utf-8')

describe('App navigation & routes (issue #69)', () => {
  it('imports the two new pages', () => {
    expect(appSrc).toContain("import ResourcePage")
    expect(appSrc).toContain("import AcknowledgmentPage")
  })

  it('sidebar has Resource and Acknowledgment entries', () => {
    expect(appSrc).toContain("label: 'Resource'")
    expect(appSrc).toContain("label: 'Acknowledgment'")
  })

  it('defines /resource and /acknowledgment routes', () => {
    expect(appSrc).toContain('path="/resource"')
    expect(appSrc).toContain('path="/acknowledgment"')
  })

  it('protects the new routes with ProtectedRoute', () => {
    expect(appSrc).toMatch(/path="\/resource"[\s\S]{0,80}ProtectedRoute/)
    expect(appSrc).toMatch(/path="\/acknowledgment"[\s\S]{0,80}ProtectedRoute/)
  })

  it('no longer references the inline VideosSection', () => {
    expect(appSrc).not.toContain('<VideosSection')
    expect(appSrc).not.toContain('function VideosSection')
  })
})

describe('Running credit line (issue #69)', () => {
  it('PageHeader renders a credit line driven by the CREDIT data', () => {
    expect(appSrc).toContain('page-credit')
    expect(appSrc).toContain('CREDIT.prefix')
    expect(appSrc).toContain('CREDIT.parts')
  })

  it('imports CREDIT from the links module', () => {
    expect(appSrc).toContain("import { CREDIT }")
  })
})
