import { describe, it, expect } from 'vitest'
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
