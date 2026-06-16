import { describe, it, expect, vi } from 'vitest'
import { generateFilename, exportToPDF, exportToPNG } from './export.js'

const { html2canvasMock } = vi.hoisted(() => ({ html2canvasMock: vi.fn() }))
vi.mock('html2canvas', () => ({ default: html2canvasMock }))

describe('generateFilename', () => {
  it('generates standard filename', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('csmf_table', 'InterVA', 'abcd1234-5678', 'csv')
    expect(result).toBe('csmf_table_InterVA_abcd1234_20240615.csv')
    vi.useRealTimers()
  })

  it('replaces spaces in algorithm name with underscores', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('chart', 'In Silico VA', 'abcd1234-5678', 'png')
    expect(result).toBe('chart_In_Silico_VA_abcd1234_20240615.png')
    vi.useRealTimers()
  })

  it('uses "unknown" for null algorithm', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('matrix', null, 'abcd1234', 'csv')
    expect(result).toBe('matrix_unknown_abcd1234_20240615.csv')
    vi.useRealTimers()
  })

  it('uses "job" for null jobId', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('matrix', 'EAVA', null, 'csv')
    expect(result).toBe('matrix_EAVA_job_20240615.csv')
    vi.useRealTimers()
  })

  it('uses "unknown" and "job" for both null', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('export', null, null, 'csv')
    expect(result).toBe('export_unknown_job_20240615.csv')
    vi.useRealTimers()
  })

  it('truncates jobId to 8 characters', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('data', 'InterVA', 'abcdefgh-ijklmnop', 'csv')
    expect(result).toBe('data_InterVA_abcdefgh_20240615.csv')
    vi.useRealTimers()
  })

  it('handles short jobId without truncating', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('data', 'InterVA', 'abc', 'csv')
    expect(result).toBe('data_InterVA_abc_20240615.csv')
    vi.useRealTimers()
  })

  it('handles different extensions', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
    const result = generateFilename('chart', 'InterVA', 'abcd1234', 'png')
    expect(result).toBe('chart_InterVA_abcd1234_20240615.png')
    vi.useRealTimers()
  })
})

describe('full-width capture (issue #78)', () => {
  it('captures the full element scrollWidth, not just the visible width', async () => {
    html2canvasMock.mockReset()
    html2canvasMock.mockResolvedValue({ toBlob: (cb) => cb(null) })

    const el = { scrollWidth: 1234, scrollHeight: 567 }
    await exportToPNG({ current: el }, 'csmf_chart.png')

    expect(html2canvasMock).toHaveBeenCalledTimes(1)
    const opts = html2canvasMock.mock.calls[0][1]
    expect(opts.width).toBe(1234)
    expect(opts.height).toBe(567)
    expect(opts.windowWidth).toBe(1234)
  })

  it('un-clips the overflowing CSMF facet row in the cloned DOM', async () => {
    html2canvasMock.mockReset()
    html2canvasMock.mockResolvedValue({ toBlob: (cb) => cb(null) })

    await exportToPNG({ current: { scrollWidth: 800, scrollHeight: 400 } }, 'csmf_chart.png')
    const { onclone } = html2canvasMock.mock.calls[0][1]

    const facets = { style: {} }
    onclone({ querySelectorAll: (sel) => (sel === '.csmf-facets' ? [facets] : []) })
    expect(facets.style.overflow).toBe('visible')
    expect(facets.style.width).toBe('max-content')
  })
})

describe('exportToPDF', () => {
  it('is a function', () => {
    expect(typeof exportToPDF).toBe('function')
  })

  it('rejects with invalid element ref', async () => {
    // Should not throw, just log error
    await exportToPDF(null, 'test.pdf')
    await exportToPDF({ current: null }, 'test.pdf')
    // No crash = pass
  })
})
