import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { createMemoryRouter } from 'react-router-dom'

const __dir = dirname(fileURLToPath(import.meta.url))
const mainSrc = readFileSync(resolve(__dir, 'main.jsx'), 'utf-8')
const basename = mainSrc.match(/basename="([^"]*)"/)?.[1]

describe('Router basename (direct-URL home page bug)', () => {
  it('main.jsx sets a basename', () => {
    expect(basename).toBeTruthy()
  })

  it('basename has no trailing slash (React Router convention)', () => {
    expect(basename).toBe('/comsa-dashboard')
  })

  // On basename mismatch the router doesn't return zero matches — it
  // synthesizes a 404 error state, so assert on state.errors.
  it('matches the home route when the URL has no trailing slash', () => {
    const router = createMemoryRouter(
      [{ path: '/', element: null }],
      { basename, initialEntries: ['/comsa-dashboard'] }
    )
    expect(router.state.errors).toBeNull()
  })

  it('still matches deep routes like /login', () => {
    const router = createMemoryRouter(
      [{ path: '/login', element: null }],
      { basename, initialEntries: ['/comsa-dashboard/login'] }
    )
    expect(router.state.errors).toBeNull()
  })
})
