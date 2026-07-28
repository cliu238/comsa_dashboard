import { describe, it, expect, vi } from 'vitest'

/**
 * Issue #105 -- "inactive Calibrate button".
 *
 * age_group MUST travel to the backend in the QUERY STRING, never as a
 * multipart form field.
 *
 * Why: plumber 1.3.2 assigns a multipart text part no Content-Type (and it has
 * no filename), so parser_picker() falls through to parsers$alias$form ==
 * parser_text(parseQS). parseQS interprets the raw part value as a URL-encoded
 * query string, so a bare value like "child" -- which contains no "=" -- parses
 * to an empty list. req$args$age_group then arrives as list() (length 0) and the
 * backend cannot tell it apart from a missing parameter.
 *
 * Consequence when this regressed: a child upload was scored against the
 * NEONATE broad-cause list, so hiv / other_infections / severe_malnutrition were
 * all reported "unrecognized", has_errors became true, and JobForm disabled the
 * Calibrate button (1334 of 2383 records). submitJob has always sent its scalars
 * via URLSearchParams, which is exactly why job submission was unaffected while
 * the preview was broken.
 */
describe('previewMapping age_group transport (issue #105)', () => {
  const mockOk = (body = { reports: {} }) => vi.fn().mockResolvedValue({
    ok: true, status: 200, json: () => Promise.resolve(body)
  })

  it('sends age_group in the query string, not as a multipart field', async () => {
    const mockFetch = mockOk()
    globalThis.fetch = mockFetch

    const { previewMapping } = await import('./client.js')
    const file = new File(['ID,cause\n1,hiv\n'], 'eava.csv', { type: 'text/csv' })
    await previewMapping({ uploads: [{ algorithm: 'EAVA', file }], ageGroup: 'child' })

    const [url, options] = mockFetch.mock.calls[0]

    // The value must be readable from req$argsQuery.
    expect(new URL(url, 'http://localhost').searchParams.get('age_group')).toBe('child')

    // And must NOT be smuggled through the multipart body, where parseQS eats it.
    expect(options.body.get('age_group')).toBeNull()
  })

  it('sends age_group=neonate in the query string too (no reliance on a backend default)', async () => {
    const mockFetch = mockOk()
    globalThis.fetch = mockFetch

    const { previewMapping } = await import('./client.js')
    const file = new File(['ID,cause\n1,Prematurity\n'], 'interva.csv', { type: 'text/csv' })
    await previewMapping({ uploads: [{ algorithm: 'InterVA', file }], ageGroup: 'neonate' })

    const [url] = mockFetch.mock.calls[0]
    expect(new URL(url, 'http://localhost').searchParams.get('age_group')).toBe('neonate')
  })

  it('still sends the uploaded files as multipart form data', async () => {
    const mockFetch = mockOk()
    globalThis.fetch = mockFetch

    const { previewMapping } = await import('./client.js')
    const file = new File(['ID,cause\n1,hiv\n'], 'eava.csv', { type: 'text/csv' })
    await previewMapping({ uploads: [{ algorithm: 'EAVA', file }], ageGroup: 'child' })

    const [, options] = mockFetch.mock.calls[0]
    // Single upload sends both `file` and `file_<algo>` (existing convention).
    expect(options.body.get('file')).toBeInstanceOf(File)
    expect(options.body.get('file_eava')).toBeInstanceOf(File)
  })

  it('preserves the age_group choice for multi-algorithm previews', async () => {
    const mockFetch = mockOk()
    globalThis.fetch = mockFetch

    const { previewMapping } = await import('./client.js')
    await previewMapping({
      uploads: [
        { algorithm: 'EAVA', file: new File(['a'], 'eava.csv') },
        { algorithm: 'InterVA', file: new File(['b'], 'interva.csv') },
      ],
      ageGroup: 'child',
    })

    const [url, options] = mockFetch.mock.calls[0]
    expect(new URL(url, 'http://localhost').searchParams.get('age_group')).toBe('child')
    expect(options.body.get('file_eava')).toBeInstanceOf(File)
    expect(options.body.get('file_interva')).toBeInstanceOf(File)
    expect(options.body.get('age_group')).toBeNull()
  })
})
