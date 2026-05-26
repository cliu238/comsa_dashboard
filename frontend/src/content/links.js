// Single source of truth for external links and citations used by the
// Resource and Acknowledgment pages (issue #69). URLs verified live 2026-05-26.

export const PACKAGE_LINKS = {
  github: 'https://github.com/sandy-pramanik/vacalibration',
  cran: 'https://cran.r-project.org/package=vacalibration',
};

// The 4 references cited on pg. 17 of the vacalibration CRAN manual.
export const REFERENCES = [
  {
    authors: 'Pramanik S, et al.',
    year: 2026,
    title: 'Country-Specific Estimates of Misclassification Rates of Computer-Coded Verbal Autopsy Algorithms',
    venue: 'BMJ Global Health',
    url: 'https://doi.org/10.1136/bmjgh-2025-021747',
  },
  {
    authors: 'Pramanik S, et al.',
    year: 2025,
    title: 'Modeling structure and country-specific heterogeneity in misclassification matrices of verbal autopsy-based cause of death classifiers',
    venue: 'Annals of Applied Statistics',
    url: 'https://doi.org/10.1214/24-AOAS2006',
  },
  {
    authors: 'Fiksel J, et al.',
    year: 2022,
    title: 'Generalized Bayes Quantification Learning under Dataset Shift',
    venue: 'Journal of the American Statistical Association',
    url: 'https://www.tandfonline.com/doi/full/10.1080/01621459.2021.1909599',
  },
  {
    authors: 'Datta A, et al.',
    year: 2021,
    title: 'Regularized Bayesian transfer learning for population-level etiological distributions',
    venue: 'Biostatistics',
    url: 'https://doi.org/10.1093/biostatistics/kxaa001',
  },
];

// Moved out of the job form (was JobForm.jsx:497).
export const SAMPLE_DATA_SOURCE = {
  text: 'Source: Pramanik S, Wilson E, Fiksel J, Gilbert B, Datta A (2025). vacalibration: Calibration of Computer-Coded Verbal Autopsy Algorithm. R package version 2.0. COMSA Mozambique data.',
  url: 'https://github.com/sandy-pramanik/vacalibration',
};

export const AWARD = {
  title: '2024 Data Science and AI Institute Demonstration Projects Award',
  url: 'https://ai.jhu.edu/news/data-science-and-ai-institute-announces-inaugural-demonstration-projects-award-recipients-2024/',
};

export const ORGS = {
  dsai: { name: 'Johns Hopkins Data Science and AI Institute (DSAI)', url: 'https://ai.jhu.edu/' },
  biostat: { name: 'Department of Biostatistics', url: 'https://publichealth.jhu.edu/departments/biostatistics' },
  intlHealth: { name: 'Department of International Health', url: 'https://publichealth.jhu.edu/departments/international-health' },
};

// Running credit shown under every page title. Wording is verbatim from issue #69.
export const CREDIT = {
  prefix: 'Designed and maintained by ',
  parts: [
    { label: 'DSAI', url: ORGS.dsai.url },
    { label: 'Dept of Biostat', url: ORGS.biostat.url },
    { label: 'Dept of International Health', url: ORGS.intlHealth.url },
  ],
  suffix: ' at Johns Hopkins',
};

// Award investigators — 2024 DSAI Demonstration Projects Award (issue #69). Shape: { name, role, affiliation, url?, photo? }
export const INVESTIGATORS = [
  { name: 'Agbessi Amouzou', role: 'Professor', affiliation: 'Department of International Health', url: 'https://publichealth.jhu.edu/faculty/2047/agbessi-amouzou' },
  { name: 'Abhirup Datta', role: 'Associate Professor', affiliation: 'Department of Biostatistics', url: 'https://publichealth.jhu.edu/faculty/3332/abhirup-datta' },
  { name: 'Almamy Malick Kante', role: 'Associate Scientist', affiliation: 'Department of International Health', url: 'https://publichealth.jhu.edu/faculty/3482/almamy-malick-kante' },
  { name: 'Sandipan Pramanik', role: 'Postdoctoral Fellow', affiliation: 'Department of Biostatistics', url: 'https://github.com/sandy-pramanik' },
  { name: 'Fred Van Dyk', role: 'Software Engineer', affiliation: 'Department of International Health' },
  { name: 'Emily Wilson', role: 'Senior Research Associate', affiliation: 'Department of International Health', url: 'https://publichealth.jhu.edu/faculty/2683/emily-b-wilson' },
  { name: 'Emma Williams', role: 'Senior Research Associate', affiliation: 'Department of International Health', url: 'https://publichealth.jhu.edu/faculty/1994/emma-williams' },
  { name: 'Scott Zeger', role: 'John C. Malone Professor', affiliation: 'Department of Biostatistics', url: 'https://publichealth.jhu.edu/faculty/784/scott-l-zeger' },
];

// DSAI contributors who built the platform (issue #69).
export const CONTRIBUTORS = [
  { name: 'Eric Liu', role: 'Lead Developer', affiliation: 'Data Science and AI Institute, Johns Hopkins', url: 'https://github.com/cliu238' },
  { name: 'Sandipan Pramanik', role: 'vacalibration R package author', affiliation: 'Department of Biostatistics', url: 'https://github.com/sandy-pramanik' },
  { name: 'Emily Wilson', role: 'Senior Research Associate', affiliation: 'Department of International Health', url: 'https://publichealth.jhu.edu/faculty/2683/emily-b-wilson' },
];
