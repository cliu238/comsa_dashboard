/** @vitest-environment jsdom */
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import AcknowledgmentPage, { InvestigatorCard } from './AcknowledgmentPage'
import { AWARD } from '../content/links'

describe('AcknowledgmentPage', () => {
  it('renders the award link pointing to the DSAI announcement', () => {
    render(<AcknowledgmentPage />)
    const link = screen.getByRole('link', { name: AWARD.title })
    expect(link.getAttribute('href')).toBe(AWARD.url)
  })

  it('renders Investigators and Contributors headings', () => {
    render(<AcknowledgmentPage />)
    expect(screen.getByText('Investigators')).toBeTruthy()
    expect(screen.getByText('Contributors')).toBeTruthy()
  })
})

describe('InvestigatorCard', () => {
  it('shows a photo when one is provided', () => {
    render(<InvestigatorCard person={{ name: 'Jane Doe', photo: 'jane.jpg', url: 'https://example.org/jane' }} />)
    const img = screen.getByRole('img', { name: 'Jane Doe' })
    expect(img.getAttribute('src')).toMatch(/jane\.jpg$/)
    expect(screen.getByRole('link', { name: 'Jane Doe' }).getAttribute('href')).toBe('https://example.org/jane')
  })

  it('falls back to initials when no photo is provided', () => {
    render(<InvestigatorCard person={{ name: 'Jane Doe' }} />)
    expect(screen.queryByRole('img')).toBeNull()
    expect(screen.getByText('JD')).toBeTruthy()
  })
})
