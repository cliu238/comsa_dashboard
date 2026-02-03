---
name: vacalibration
description: R package for calibrating verbal autopsy cause-of-death classifications using Bayesian methods
---

# vacalibration

R package for calibrating population-level cause-specific mortality fractions (CSMFs) from computer-coded verbal autopsy (CCVA) algorithms.

## Description

This package calibrates CSMF estimates produced by CCVA algorithms on WHO-standardized verbal autopsy surveys. It uses uncertainty-quantified misclassification matrices from the CHAMPS project to improve accuracy of cause-of-death assignments.

**Repository:** [sandy-pramanik/vacalibration](https://github.com/sandy-pramanik/vacalibration)
**Language:** R (98.7%), Stan (1.2%)
**License:** MIT

## When to Use This Skill

Use this skill when working with:
- Verbal autopsy (VA) data analysis
- Cause-specific mortality fraction (CSMF) estimation
- CCVA algorithm outputs (EAVA, InSilicoVA, InterVA)
- Bayesian calibration of classifier predictions
- Child and neonatal mortality studies

## Key Features

### Supported Algorithms
- **EAVA** - Expert Algorithm for VA
- **InSilicoVA** - Probabilistic VA interpretation
- **InterVA** - Interpretive VA model

### Supported Age Groups
- **Neonates:** 0-27 days
- **Children:** 1-59 months

### Supported Countries
Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra Leone, South Africa, plus "other" for all other countries

### Calibration Types
- **Algorithm-specific:** Calibrate single algorithm output
- **Ensemble:** Combine multiple algorithms for robust estimates
- **Custom cause mapping:** Map study causes to CHAMPS broad causes

## Installation

```r
install.packages("vacalibration")
library(vacalibration)
```

## Core API

### Main Function: `vacalibration()`

```r
vacalibration(
  va_data,              # Named list of CCVA outputs by algorithm
  age_group,            # "neonate" or "child"
  country,              # Country name (for pre-built matrices)
  calibmodel.type,      # "Mmatprior" (default) or "Mmatfixed"
  ensemble,             # TRUE (default) for ensemble calibration
  nMCMC = 5000,         # Number of MCMC iterations
  nBurn = 5000,         # Number of burn-in iterations
  nThin = 1,            # Thinning interval
  plot_it = TRUE,       # Generate diagnostic plots
  verbose = TRUE        # Print progress messages
)
```

### Output Structure

```r
result$p_uncalib          # Uncalibrated CSMF estimates [algo, cause]
result$pcalib_postsumm    # Posterior summary [algo, stat, cause]
                          #   stat: "postmean", "lowcredI", "upcredI"
result$Mmat.asDirich      # Misclassification matrix (Dirichlet params)
                          #   3D: [algo, champs_cause, va_cause]
                          #   2D: [champs_cause, va_cause] for single algo
```

## Usage Examples

### Algorithm-Specific Calibration

```r
# EAVA calibration for neonates in Mozambique
vacalib_eava <- vacalibration(
  va_data = list("eava" = comsamoz_CCVAoutput$neonate$eava),
  age_group = "neonate",
  country = "Mozambique"
)

# Access results
vacalib_eava$p_uncalib[1,]        # Uncalibrated CSMF
vacalib_eava$pcalib_postsumm[1,,] # Calibrated CSMF with uncertainty
```

### Ensemble Calibration

```r
# Combine all three algorithms
vacalib_ensemble <- vacalibration(
  va_data = list(
    "eava" = comsamoz_CCVAoutput$neonate$eava,
    "insilicova" = comsamoz_CCVAoutput$neonate$insilicova,
    "interva" = comsamoz_CCVAoutput$neonate$interva
  ),
  age_group = "neonate",
  country = "Mozambique"
)

# Algorithm-specific and ensemble results
vacalib_ensemble$pcalib_postsumm["eava",,]
vacalib_ensemble$pcalib_postsumm["ensemble",,]
```

### Custom Cause Mapping (CA CODE Data)

```r
# Map study causes to CHAMPS broad causes
cause_map <- c(
  "Intrapartum" = "ipre",
  "Congenital" = "congenital_malformation",
  "Diarrhoeal" = "sepsis_meningitis_inf",
  "LRI" = "pneumonia",
  "Sepsis" = "sepsis_meningitis_inf",
  "Preterm" = "prematurity",
  "Tetanus" = "sepsis_meningitis_inf",
  "Other" = "other"
)

vacalib_cacode <- vacalibration(
  va_data = list("eava" = c(
    "Intrapartum" = 82, "Congenital" = 17,
    "Diarrhoeal" = 6, "LRI" = 33,
    "Sepsis" = 108, "Preterm" = 35,
    "Tetanus" = 14, "Other" = 7
  )),
  age_group = "neonate",
  country = "Bangladesh",
  studycause_map = cause_map
)
```

## Included Data

### `CCVA_missmat`
Pre-computed misclassification matrices for all algorithm/age/country combinations. Contains:
- Prior distributions for Bayesian calibration
- Average matrices for fixed calibration
- Posterior samples available from [GitHub repo](https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices)

### `comsamoz_CCVAoutput`
Example CCVA outputs from Mozambique COMSA study for testing.

## Calibration Model Types

Control with `calibmodel.type`:
- `"Mmatprior"` (default): Use Dirichlet prior for misclassification matrix, full Bayesian uncertainty propagation
- `"Mmatfixed"`: Use fixed (average) misclassification matrix, no uncertainty propagation

## CHAMPS Broad Causes

Standard cause categories used by the package:
- `ipre` - Intrapartum-related events
- `prematurity` - Preterm complications
- `sepsis_meningitis_inf` - Sepsis/meningitis/infections
- `pneumonia` - Lower respiratory infections
- `congenital_malformation` - Congenital anomalies
- `other` - Other causes

## References

- [Pramanik et al. (2025)](https://doi.org/10.1214/24-AOAS2006) - Methodological framework
- [Pramanik et al. (2025+)](https://doi.org/10.1101/2025.07.02.25329250) - Analysis details
- [CHAMPS Project](https://champshealth.org/) - Data source

