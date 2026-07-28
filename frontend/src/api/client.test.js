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
      ok: true, status: 200,
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
      ok: true, status: 200,
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

    const [, options] = mockFetch.mock.calls[0];
    const formData = options.body;
    expect(formData.get('file')).toBeTruthy();
    expect(formData.get('file_interva')).toBeNull();
  });

  it('sends per-algorithm file keys for multi-file vacalibration even when ensemble is OFF (issue #83)', async () => {
    // Independent multi-algorithm calibration: each algorithm keeps its own file
    // regardless of "Combine algorithms?". Previously only the first file was
    // sent, silently dropping the rest.
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true, status: 200,
      json: () => Promise.resolve({ job_id: 'test-789', status: 'pending' })
    });
    globalThis.fetch = mockFetch;

    const { submitJob } = await import('./client.js');
    await submitJob({
      uploads: [
        { algorithm: 'InterVA', file: new File(['a'], 'interva.csv') },
        { algorithm: 'InSilicoVA', file: new File(['b'], 'insilicova.csv') }
      ],
      jobType: 'vacalibration',
      algorithms: ['InterVA', 'InSilicoVA'],
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
    expect(formData.get('file_interva')).toBeTruthy();
    expect(formData.get('file_insilicova')).toBeTruthy();
    expect(formData.get('file')).toBeNull();      // no single-file fallback
    expect(url).toContain('ensemble=false');
  });
})

describe('previewMapping', () => {
  it('posts one file per algorithm and returns reports', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true, status: 200,
      json: () => Promise.resolve({ reports: { interva: { total_records: 3, has_errors: false } } })
    });
    globalThis.fetch = mockFetch;

    const { previewMapping } = await import('./client.js');
    const file = new File(['ID,cause\n1,Prematurity\n'], 'interva.csv', { type: 'text/csv' });
    const res = await previewMapping({
      uploads: [{ algorithm: 'InterVA', file }],
      ageGroup: 'neonate'
    });

    expect(res.reports.interva.total_records).toBe(3);
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toContain('/jobs/preview');
    expect(options.method).toBe('POST');
    expect(options.body.get('file_interva')).toBeInstanceOf(File);
    // age_group rides in the query string, not the multipart body -- plumber's
    // form parser destroys bare text parts (issue #105).
    expect(url).toContain('age_group=neonate');
  });
})
