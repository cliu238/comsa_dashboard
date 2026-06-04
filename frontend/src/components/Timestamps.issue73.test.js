import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const detailSrc = readFileSync(resolve(__dir, 'JobDetail.jsx'), 'utf-8')
const listSrc = readFileSync(resolve(__dir, 'JobList.jsx'), 'utf-8')

describe('Timestamps use the shared timezone-labeled formatter (issue #73)', () => {
  it('JobDetail imports and uses formatTimestamp for the time rows', () => {
    expect(detailSrc).toContain("from '../utils/datetime'")
    expect(detailSrc).toContain('formatTimestamp(status.created_at)')
    expect(detailSrc).toContain('formatTimestamp(status.started_at)')
    expect(detailSrc).toContain('formatTimestamp(status.completed_at)')
  })
  it('JobList imports and uses formatTimestamp for the created column', () => {
    expect(listSrc).toContain("from '../utils/datetime'")
    expect(listSrc).toContain('formatTimestamp(job.created_at)')
    expect(listSrc).not.toContain('new Date(job.created_at).toLocaleString()')
  })
})
