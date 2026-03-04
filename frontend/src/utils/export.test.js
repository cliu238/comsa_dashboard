import { describe, it, expect, vi } from 'vitest'
import { generateFilename } from './export.js'

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
