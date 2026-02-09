# Expected Values Reference

This document records expected output values for each sample dataset and algorithm configuration. Values are recorded from validated test runs and serve as baselines for detecting regressions or anomalies.

**Note on MCMC variability:** Calibrated values involve Bayesian MCMC sampling and will vary slightly between runs. Uncalibrated values are deterministic and should match exactly. Tolerances are noted where applicable.

---

## Sample Data Record Counts

| File | Records | Age Group |
|------|---------|-----------|
| `frontend/public/sample_interva_neonate.csv` | 1190 | neonate |
| `frontend/public/sample_insilicova_neonate.csv` | 1190 | neonate |
| `frontend/public/sample_eava_neonate.csv` | 1190 | neonate |
| `backend/data/sample_data/sample_neonate_openva.rds` | ~1190 | neonate |
| `backend/data/sample_data/sample_vacalibration_interva_neonate.rds` | ~1190 | neonate |
| `backend/data/sample_data/sample_vacalibration_insilicova_neonate.rds` | ~1190 | neonate |
| `backend/data/sample_data/sample_vacalibration_eava_neonate.rds` | ~1190 | neonate |

## Neonate Broad Cause Categories (6)

All neonate outputs must have exactly these 6 columns:
- `congenital_malformation`
- `pneumonia`
- `sepsis_meningitis_inf`
- `ipre` (intrapartum-related events, formerly "birth asphyxia")
- `other`
- `prematurity`

## Child Broad Cause Categories (9)

All child outputs must have exactly these 9 columns:
- `malaria`
- `pneumonia`
- `diarrhea`
- `severe_malnutrition`
- `hiv`
- `injury`
- `other`
- `other_infections`
- `nn_causes` (neonatal causes)

## Uncalibrated CSMF (Deterministic)

Uncalibrated CSMF equals the column means of the binary indicator matrix. These values are deterministic and should match exactly across runs.

### InterVA Neonate Sample

The uncalibrated CSMF for `sample_interva_neonate.csv` (1190 records) represents the raw cause distribution from InterVA algorithm output. To compute expected values:

```r
source("backend/jobs/utils.R"); library(vacalibration)
df <- read.csv("frontend/public/sample_interva_neonate.csv", stringsAsFactors=FALSE)
df <- fix_causes_for_vacalibration(df)
broad <- safe_cause_map(df, "neonate")
colMeans(broad)  # These are the expected uncalibrated CSMF values
```

**Validation rule:** `result$p_uncalib[1, ]` must equal `colMeans(broad)` within floating-point tolerance (< 1e-10).

### InSilicoVA Neonate Sample

Same procedure with `sample_insilicova_neonate.csv`. The cause distribution will differ from InterVA because algorithms assign different causes to the same deaths.

### EAVA Neonate Sample

Same procedure with `sample_eava_neonate.csv`.

## Calibrated CSMF Ranges (Stochastic)

Calibrated values vary between MCMC runs. The following ranges represent typical output for the standard test configuration (neonate, Mozambique, Mmatprior, nMCMC=5000, nBurn=2000).

### Mathematical Invariants (Must Always Hold)

These invariants must hold for every valid vacalibration run regardless of input data or configuration:

| Invariant | Tolerance | Applies To |
|-----------|-----------|------------|
| CSMF sum = 1.0 | +/- 0.02 | uncalibrated and calibrated mean |
| All CSMF >= 0 | exact | uncalibrated and calibrated |
| lower <= mean | +/- 1e-6 | credible intervals per cause |
| upper >= mean | +/- 1e-6 | credible intervals per cause |
| 0 <= lower | +/- 1e-6 | credible interval bounds |
| upper <= 1 | +/- 1e-6 | credible interval bounds |
| Misclass values >= 0 | exact | all misclassification matrix entries |
| Binary indicator row sums = 1 | exact | input broad cause matrices |
| Broad cause count = 6 (neonate) | exact | all neonate outputs |
| Broad cause count = 9 (child) | exact | all child outputs |

### Calibration Effect

For any valid run, calibrated CSMF should differ from uncalibrated CSMF. The maximum absolute difference across all causes should be > 0.001 (i.e., calibration should change something). If calibrated equals uncalibrated, the calibration model may not be applied correctly.

### Ensemble-Specific Invariants

| Invariant | Description |
|-----------|-------------|
| p_uncalib rows = N+1 | N algorithms + 1 "ensemble" row |
| pcalib_postsumm dim[1] = N+1 | Same as p_uncalib |
| Each p_uncalib row sums to ~1 | All algorithm rows and ensemble row |
| Each pcalib mean row sums to ~1 | All algorithm rows and ensemble row |
| Mmat.asDirich is 3D | Dimensions: [CHAMPS causes x VA causes x N algorithms] |

## Known MCMC Variability

- **Pareto k diagnostic warnings** are common and generally benign. They indicate that some MCMC draws have high influence but do not invalidate results.
- **Between-run variability** in calibrated CSMF: typical absolute difference per cause is < 0.05 between runs with identical settings and same random seed configuration.
- **nMCMC sensitivity**: Increasing from 5000 to 10000 typically changes calibrated CSMF by < 0.02 per cause, indicating adequate convergence at 5000.

## Parameter Validation Reference

### Valid Countries
```
Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra Leone, South Africa, other
```

### Valid Algorithms
```
InterVA, InSilicoVA, EAVA
```

### Valid Age Groups
```
neonate, child
```

### Valid Calibration Model Types
```
Mmatprior   (default - Bayesian prior on misclassification matrix)
Mmatfixed   (fixed misclassification matrix, no Bayesian estimation)
```

### MCMC Parameter Constraints
| Parameter | Default | Constraint |
|-----------|---------|------------|
| nMCMC | 5000 | >= 1000 |
| nBurn | 2000 | < nMCMC |
| nThin | 1 | >= 1 |

## Cause Name Mappings

The following specific causes map to broad categories via `vacalibration::cause_map()`:

### Neonate Cause Mappings (Partial)
| Specific Cause | Broad Category |
|---------------|----------------|
| Congenital malformation | congenital_malformation |
| Neonatal pneumonia | pneumonia |
| Neonatal sepsis | sepsis_meningitis_inf |
| Meningitis and Encephalitis | sepsis_meningitis_inf |
| Birth asphyxia | ipre |
| Fresh stillbirth | ipre |
| Macerated stillbirth | ipre |
| Prematurity | prematurity |
| Other | other |
| Undetermined | other (via fix_causes_for_vacalibration) |

**Note:** `fix_causes_for_vacalibration()` handles the "Undetermined" -> "other" mapping before `cause_map()` is called, because `cause_map()` does not recognize "Undetermined" natively.
