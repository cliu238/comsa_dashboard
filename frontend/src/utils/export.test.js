import { describe, it, expect, vi, beforeEach } from 'vitest'
import { generateFilename, exportToPDF, exportToPNG, exportCombinedPDF } from './export.js'

const { html2canvasMock } = vi.hoisted(() => ({ html2canvasMock: vi.fn() }))
vi.mock('html2canvas', () => ({ default: html2canvasMock }))

const { jsPDFMock, pdfInstance } = vi.hoisted(() => {
  const inst = {
    internal: { pageSize: { getWidth: () => 595, getHeight: () => 842 } },
    addImage: vi.fn(),
    addPage: vi.fn(),
    save: vi.fn(),
  }
  // Regular function (not arrow) so it can be invoked with `new`.
  return { jsPDFMock: vi.fn(function () { return inst }), pdfInstance: inst }
})
vi.mock('jspdf', () => ({ jsPDF: jsPDFMock }))

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

describe('exportCombinedPDF (issue #91)', () => {
  beforeEach(() => {
    html2canvasMock.mockReset()
    jsPDFMock.mockClear()
    pdfInstance.addImage.mockClear()
    pdfInstance.addPage.mockClear()
    pdfInstance.save.mockClear()
    // jsdom is not active for this file; stub the browser-only error fallback.
    vi.stubGlobal('alert', vi.fn())
  })

  const makeRef = () => ({ current: { scrollWidth: 800, scrollHeight: 400 } })

  it('no-ops when no valid sections are provided', async () => {
    await exportCombinedPDF([], 'report.pdf')
    await exportCombinedPDF([{ ref: null }, { ref: { current: null } }], 'report.pdf')
    expect(jsPDFMock).not.toHaveBeenCalled()
    expect(pdfInstance.save).not.toHaveBeenCalled()
  })

  it('captures every valid section and adds one image each, then saves once', async () => {
    html2canvasMock.mockResolvedValue({ width: 1000, height: 500, toDataURL: () => 'data:img' })

    await exportCombinedPDF(
      [
        { ref: makeRef(), title: 'Inputs' },
        { ref: { current: null } },            // skipped (e.g. no misclass matrix)
        { ref: makeRef(), title: 'CSMF chart' },
        { ref: makeRef(), title: 'CSMF table' },
      ],
      'combined_report.pdf'
    )

    expect(html2canvasMock).toHaveBeenCalledTimes(3) // only the 3 valid sections
    expect(pdfInstance.addImage).toHaveBeenCalledTimes(3)
    expect(pdfInstance.save).toHaveBeenCalledWith('combined_report.pdf')
  })

  it('paginates: a section that does not fit the remaining space starts a new page', async () => {
    // Tall canvases (height >> width) each consume ~a full page, so the 2nd and
    // 3rd sections must each trigger addPage.
    html2canvasMock.mockResolvedValue({ width: 1000, height: 3000, toDataURL: () => 'data:img' })

    await exportCombinedPDF(
      [{ ref: makeRef() }, { ref: makeRef() }, { ref: makeRef() }],
      'combined_report.pdf'
    )

    expect(pdfInstance.addImage).toHaveBeenCalledTimes(3)
    expect(pdfInstance.addPage).toHaveBeenCalledTimes(2) // 3 full-page sections => 2 page breaks
  })

  it('does not crash on capture failure', async () => {
    html2canvasMock.mockRejectedValue(new Error('canvas boom'))
    await exportCombinedPDF([{ ref: makeRef() }], 'report.pdf')
    expect(pdfInstance.save).not.toHaveBeenCalled()
  })
})
