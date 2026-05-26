/** @vitest-environment jsdom */
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import ResourcePage from './ResourcePage'
import { REFERENCES, PACKAGE_LINKS } from '../content/links'

describe('ResourcePage', () => {
  it('renders an outbound link for every reference', () => {
    render(<ResourcePage />)
    const hrefs = screen.getAllByRole('link').map((a) => a.getAttribute('href'))
    REFERENCES.forEach((r) => expect(hrefs).toContain(r.url))
  })

  it('renders the GitHub and CRAN package links', () => {
    render(<ResourcePage />)
    const hrefs = screen.getAllByRole('link').map((a) => a.getAttribute('href'))
    expect(hrefs).toContain(PACKAGE_LINKS.github)
    expect(hrefs).toContain(PACKAGE_LINKS.cran)
  })

  it('shows the moved sample-data source citation', () => {
    render(<ResourcePage />)
    expect(screen.getByText(/Pramanik S, Wilson E/)).toBeTruthy()
  })

  it('includes the Introduction Videos section', () => {
    render(<ResourcePage />)
    expect(screen.getByText('Introduction Videos')).toBeTruthy()
  })

  it('all outbound links use rel="noopener noreferrer" and target="_blank"', () => {
    render(<ResourcePage />)
    screen.getAllByRole('link').forEach((a) => {
      expect(a.getAttribute('rel')).toBe('noopener noreferrer')
      expect(a.getAttribute('target')).toBe('_blank')
    })
  })
})
