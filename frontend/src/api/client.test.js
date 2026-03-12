import { describe, it, expect, vi } from 'vitest'
import { unbox } from './client.js'

describe('unbox', () => {
  it('passes through null and undefined', () => {
    expect(unbox(null)).toBeNull()
    expect(unbox(undefined)).toBeUndefined()
  })

  it('passes through primitives', () => {
    expect(unbox(42)).toBe(42)
    expect(unbox('hello')).toBe('hello')
    expect(unbox(true)).toBe(true)
  })

  it('unwraps single-element numeric array', () => {
    expect(unbox([42])).toBe(42)
  })

  it('unwraps single-element string array', () => {
    expect(unbox(['hello'])).toBe('hello')
  })

  it('does NOT unwrap single-element object array', () => {
    const input = [{ a: 1 }]
    const result = unbox(input)
    expect(Array.isArray(result)).toBe(true)
    expect(result).toHaveLength(1)
  })

  it('does NOT unwrap nested array', () => {
    const input = [[1, 2]]
    const result = unbox(input)
    expect(Array.isArray(result)).toBe(true)
  })

  it('keeps multi-element arrays, recursing into elements', () => {
    const result = unbox([[42], [99]])
    expect(result).toEqual([42, 99])
  })

  it('converts empty object to null (R NULL)', () => {
    expect(unbox({})).toBeNull()
  })

  it('recursively unboxes nested object values', () => {
    const input = { name: ['test'], count: [5] }
    expect(unbox(input)).toEqual({ name: 'test', count: 5 })
  })

  it('handles real-world R response shape', () => {
    const rResponse = {
      job_id: ['abc-123'],
      status: ['completed'],
      results: {
        csmf: {
          pneumonia: [0.15],
          prematurity: [0.35],
        },
      },
    }
    const result = unbox(rResponse)
    expect(result.job_id).toBe('abc-123')
    expect(result.status).toBe('completed')
    expect(result.results.csmf.pneumonia).toBe(0.15)
    expect(result.results.csmf.prematurity).toBe(0.35)
  })

  it('handles array of objects without unwrapping', () => {
    const input = [{ id: [1] }, { id: [2] }]
    const result = unbox(input)
    expect(result).toEqual([{ id: 1 }, { id: 2 }])
  })
})

describe('submitJob multi-file support (issue #27)', () => {
  it('sends per-algorithm file keys for ensemble vacalibration', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      json: () => Promise.resolve({ job_id: 'test-123', status: 'pending' })
    });
    globalThis.fetch = mockFetch;

    const { submitJob } = await import('./client.js');
    await submitJob({
      uploads: [
        { algorithm: 'InterVA', file: new File(['data'], 'interva.csv') },
        { algorithm: 'InSilicoVA', file: new File(['data'], 'insilicova.csv') }
      ],
      jobType: 'vacalibration',
      algorithms: ['InterVA', 'InSilicoVA'],
      ageGroup: 'neonate',
      country: 'Mozambique',
      calibModelType: 'Mmatprior',
      ensemble: true,
      nMCMC: 5000,
      nBurn: 2000,
      nThin: 1
    });

    const [url, options] = mockFetch.mock.calls[0];
    const formData = options.body;
    expect(formData.get('file_interva')).toBeTruthy();
    expect(formData.get('file_insilicova')).toBeTruthy();
    expect(formData.get('file')).toBeNull();
    expect(url).toContain('ensemble=true');
  });

  it('sends single file key for non-ensemble', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      json: () => Promise.resolve({ job_id: 'test-456', status: 'pending' })
    });
    globalThis.fetch = mockFetch;

    const { submitJob } = await import('./client.js');
    await submitJob({
      uploads: [
        { algorithm: 'InterVA', file: new File(['data'], 'test.csv') }
      ],
      jobType: 'vacalibration',
      algorithms: ['InterVA'],
      ageGroup: 'neonate',
      country: 'Mozambique',
      calibModelType: 'Mmatprior',
      ensemble: false,
      nMCMC: 5000,
      nBurn: 2000,
      nThin: 1
    });

    const [url, options] = mockFetch.mock.calls[0];
    const formData = options.body;
    expect(formData.get('file')).toBeTruthy();
    expect(formData.get('file_interva')).toBeNull();
  });
})
