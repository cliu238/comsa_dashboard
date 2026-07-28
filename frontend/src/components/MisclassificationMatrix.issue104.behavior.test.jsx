/**
 * @vitest-environment jsdom
 *
 * GitHub issue #104: "the cause names appear weird".
 *
 * The concrete defect: column headers were truncated at a fixed offset
 * (substring(0, 8) + '..'), so Sandi's display names "Neonatal sepsis" and
 * "Neonatal pneumonia" both rendered as "Neonatal.." -- two different columns
 * with identical headers, impossible to tell apart.
 *
 * Display names below are the real ones from job 901322df.
 */
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { MisclassificationMatrix } from './MisclassificationMatrix';

const DISPLAY_NAMES = {
  ipre: 'Birth asphyxia',
  other: 'Other and unspecified neonatal CoD',
  pneumonia: 'Neonatal pneumonia',
  prematurity: 'Prematurity',
  sepsis_meningitis_inf: 'Neonatal sepsis',
  congenital_malformation: 'Congenital malformation',
};

// The calibrated 5-cause slice the backend now serves for interva (issue #104):
// `other` is excluded from calibration, so it is absent from both axes.
const CAUSES_5 = [
  'congenital_malformation',
  'pneumonia',
  'sepsis_meningitis_inf',
  'ipre',
  'prematurity',
];

const INTERVA_5 = {
  matrix: [
    [0.5733, 0.0459, 0.0326, 0.1983, 0.1499],
    [0.0313, 0.4272, 0.0451, 0.2669, 0.2293],
    [0.0311, 0.0705, 0.3929, 0.2626, 0.2429],
    [0.0926, 0.0489, 0.0168, 0.6807, 0.1611],
    [0.0195, 0.0164, 0.0440, 0.2160, 0.7040],
  ],
  champs_causes: CAUSES_5,
  va_causes: CAUSES_5,
  not_calibrated: ['other'],
};

const renderMatrix = (matrixData, causeOrder) =>
  render(
    <MisclassificationMatrix
      matrixData={matrixData}
      jobId="901322df-0361-4795-aa0f-d8765401eb50"
      causeDisplayNames={DISPLAY_NAMES}
      causeOrder={causeOrder}
    />
  );

const headerTexts = (container) =>
  Array.from(container.querySelectorAll('th.va-header')).map((th) =>
    th.textContent.trim()
  );

describe('MisclassificationMatrix column headers (issue #104)', () => {
  it('renders a distinguishable header for every column', () => {
    const { container } = renderMatrix({ interva: INTERVA_5 });
    const headers = headerTexts(container);

    expect(headers).toHaveLength(5);
    expect(new Set(headers).size).toBe(headers.length);
  });

  it('does not collapse "Neonatal sepsis" and "Neonatal pneumonia" to the same header', () => {
    const { container } = renderMatrix({ interva: INTERVA_5 });
    const headers = headerTexts(container);

    // The exact regression: both used to render as "Neonatal.."
    const neonatal = headers.filter((h) => h.startsWith('Neonatal'));
    expect(neonatal).toHaveLength(2);
    expect(neonatal[0]).not.toBe(neonatal[1]);
    expect(headers.filter((h) => h === 'Neonatal..')).toHaveLength(0);
  });

  it('keeps the full cause name available as a tooltip', () => {
    const { container } = renderMatrix({ interva: INTERVA_5 });
    const titles = Array.from(
      container.querySelectorAll('th.va-header')
    ).map((th) => th.getAttribute('title'));

    expect(titles).toContain('Neonatal sepsis');
    expect(titles).toContain('Neonatal pneumonia');
  });

  it('leaves already-short headers untouched', () => {
    const { container } = renderMatrix({ interva: INTERVA_5 });
    expect(headerTexts(container)).toContain('Prematurity');
  });

  it('stays unambiguous after the causeOrder reordering', () => {
    const causeOrder = [
      'other',
      'ipre',
      'sepsis_meningitis_inf',
      'prematurity',
      'pneumonia',
      'congenital_malformation',
    ];
    const { container } = renderMatrix({ interva: INTERVA_5 }, causeOrder);
    const headers = headerTexts(container);

    expect(headers).toHaveLength(5);
    expect(new Set(headers).size).toBe(headers.length);
  });
});

describe('MisclassificationMatrix not-calibrated causes (issue #104)', () => {
  it('names the causes vacalibration excluded from calibration', () => {
    const { container } = renderMatrix({ interva: INTERVA_5 });

    expect(container.textContent).toMatch(/not calibrated/i);
    // Named with the user's own display name, not the internal broad-cause code.
    expect(container.textContent).toContain('Other and unspecified neonatal CoD');
  });

  it('says nothing about exclusions when every cause was calibrated', () => {
    const all_calibrated = {
      interva: { ...INTERVA_5, not_calibrated: [] },
    };
    const { container } = renderMatrix(all_calibrated);
    expect(container.textContent).not.toMatch(/not calibrated/i);
  });

  it('handles not_calibrated arriving as a bare string', () => {
    // db/connection.R serializes with toJSON(auto_unbox = TRUE), so a
    // single excluded cause reaches the frontend as "other", not ["other"].
    const unboxed = { interva: { ...INTERVA_5, not_calibrated: 'other' } };
    const { container } = renderMatrix(unboxed);

    expect(container.textContent).toMatch(/not calibrated/i);
    expect(container.textContent).toContain('Other and unspecified neonatal CoD');
  });

  it('handles a payload with no not_calibrated field at all', () => {
    const legacy = { interva: { ...INTERVA_5, not_calibrated: undefined } };
    const { container } = renderMatrix(legacy);
    expect(container.querySelectorAll('th.va-header')).toHaveLength(5);
    expect(container.textContent).not.toMatch(/not calibrated/i);
  });

  it('lists both excluded causes for an algorithm that excluded two', () => {
    // insilicova excluded congenital_malformation IN ADDITION to other.
    const causes4 = ['pneumonia', 'sepsis_meningitis_inf', 'ipre', 'prematurity'];
    const insilicova = {
      matrix: [
        [0.4692, 0.0651, 0.2377, 0.2280],
        [0.1583, 0.4440, 0.1568, 0.2409],
        [0.0574, 0.0258, 0.7397, 0.1770],
        [0.0446, 0.0408, 0.0435, 0.8711],
      ],
      champs_causes: causes4,
      va_causes: causes4,
      not_calibrated: ['congenital_malformation', 'other'],
    };
    const { container } = renderMatrix({ insilicova });

    expect(container.querySelectorAll('th.va-header')).toHaveLength(4);
    expect(container.textContent).toContain('Congenital malformation');
    expect(container.textContent).toContain('Other and unspecified neonatal CoD');
  });
});
