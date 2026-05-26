/** @vitest-environment jsdom */
import { describe, it, expect } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import VideosSection from './VideosSection'

describe('VideosSection', () => {
  it('is collapsed by default and expands on click', () => {
    render(<VideosSection />)
    expect(screen.queryByText('Platform Overview')).toBeNull()
    fireEvent.click(screen.getByText('Introduction Videos'))
    expect(screen.getByText('Platform Overview')).toBeTruthy()
    expect(screen.getByText('Methodology Details')).toBeTruthy()
  })

  it('renders expanded when defaultExpanded is set', () => {
    render(<VideosSection defaultExpanded />)
    expect(screen.getByText('Platform Overview')).toBeTruthy()
  })
})
