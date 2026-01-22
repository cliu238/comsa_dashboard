---
name: openVA
description: R package implementing multiple algorithms for coding cause of death from verbal autopsies
---

# openVA

R package that implements multiple open-source algorithms for coding cause of death from verbal autopsies, with tools for data manipulation and visualization.

## Description

openVA provides a unified interface to run and compare multiple verbal autopsy (VA) coding algorithms. It handles data conversion between formats, generates individual and population-level cause of death statistics, and provides visualization tools.

**Repository:** [verbal-autopsy-software/openVA](https://github.com/verbal-autopsy-software/openVA)
**Website:** [openVA.net](https://openva.net/)
**Language:** R
**CRAN:** [openVA](https://cran.r-project.org/package=openVA)

## When to Use This Skill

Use this skill when working with:
- Verbal autopsy data analysis
- Cause of death coding from VA surveys
- Comparing VA algorithm outputs (InterVA, InSilicoVA, NBC, Tariff)
- Converting VA data between WHO and PHMRC formats
- Generating CSMF (Cause-Specific Mortality Fraction) estimates
- Visualizing VA results

## Implemented VA Algorithms

| Algorithm | Description | Reference |
|-----------|-------------|-----------|
| **InterVA4** | Probabilistic model for WHO 2012 VA | Byass et al (2012) |
| **InterVA5** | Updated model for WHO 2016 VA | Byass et al (2019) |
| **InSilicoVA** | Bayesian method with uncertainty | McCormick et al (2016) |
| **NBC** | Naive Bayes Classifier | Miasnikof et al (2015) |
| **Tariff** | Tariff method replication | James et al (2011) |

## Installation

```r
# From CRAN
install.packages("openVA")

# Load package
library(openVA)
```

**Note:** Requires Java JDK for InSilicoVA. Ensure R and Java versions match (both 32-bit or both 64-bit).

## Core API

### Main Function: `codeVA()`

Run VA algorithms on your data:

```r
codeVA(
  data,                    # VA data (data.frame)
  data.type,               # "WHO2012", "WHO2016", or "PHMRC"
  model,                   # Algorithm: "InSilicoVA", "InterVA", "NBC", "Tariff"
  data.train = NULL,       # Training data (for NBC/Tariff)
  causes.train = NULL,     # Training causes (for NBC/Tariff)
  ...                      # Algorithm-specific parameters
)
```

### Result Functions

```r
# Get cause-specific mortality fractions
getCSMF(fit)

# Get top causes of death for individuals
getTopCOD(fit)

# Get individual probability matrix
getIndivProb(fit)

# Get cause category concordance
getCCC(fit)

# Calculate CSMF accuracy
getCSMF_accuracy(fit, truth)
```

### Visualization

```r
# Plot VA results (individual or population)
plotVA(fit)

# Stacked bar plot of CSMFs
stackplotVA(fit)
```

### Data Conversion

```r
# Convert between VA data formats
ConvertData(
  input,                   # Input data
  yesLabel = "Y",          # Label for "yes" responses
  noLabel = "N",           # Label for "no" responses
  missLabel = "."          # Label for missing
)

# Convert PHMRC data
ConvertData.phmrc(
  input,
  input.type = "adult"     # "adult", "child", or "neonate"
)
```

## Usage Examples

### Basic InSilicoVA Analysis

```r
library(openVA)
data(RandomVA5)

# Run InSilicoVA on WHO2016 format data
fit <- codeVA(RandomVA5,
              data.type = "WHO2016",
              model = "InSilicoVA",
              Nsim = 1000,
              auto.length = FALSE)

# View results
summary(fit)
plotVA(fit)
getCSMF(fit)
```

### Compare Multiple Algorithms

```r
# Run different algorithms
fit_insil <- codeVA(data, data.type = "WHO2016", model = "InSilicoVA")
fit_inter <- codeVA(data, data.type = "WHO2016", model = "InterVA")

# Compare CSMFs
csmf_insil <- getCSMF(fit_insil)
csmf_inter <- getCSMF(fit_inter)
```

### InterVA Analysis

```r
# InterVA5 for WHO2016 data
fit_interva <- codeVA(RandomVA5,
                      data.type = "WHO2016",
                      model = "InterVA",
                      version = "5",      # Use InterVA5
                      HIV = "l",          # HIV prevalence: h/l/v
                      Malaria = "l")      # Malaria prevalence: h/l/v
```

### NBC with Training Data

```r
# Naive Bayes with custom training data
fit_nbc <- codeVA(test_data,
                  data.type = "WHO2016",
                  model = "NBC",
                  data.train = train_data,
                  causes.train = train_causes)
```

## Included Datasets

| Dataset | Description |
|---------|-------------|
| `RandomVA5` | Synthetic WHO2016 VA data |
| `RandomVA6` | Additional synthetic data |
| `NeonatesVA5` | Neonatal VA data |
| `DataEAVA` | EAVA algorithm data |

## Data Types Supported

- **WHO2012** - WHO 2012 verbal autopsy standard
- **WHO2016** - WHO 2016 verbal autopsy standard
- **PHMRC** - Population Health Metrics Research Consortium format

## Key Parameters by Algorithm

### InSilicoVA
- `Nsim` - Number of MCMC iterations
- `auto.length` - Auto-determine chain length
- `burnin` - Burn-in iterations

### InterVA
- `version` - "4" or "5"
- `HIV` - HIV prevalence ("h", "l", "v")
- `Malaria` - Malaria prevalence ("h", "l", "v")

### NBC / Tariff
- `data.train` - Training dataset
- `causes.train` - Training cause labels

## Calibration Support

openVA integrates with vacalibration for uncertainty-quantified CSMF calibration:

```r
# Prepare data for calibration
prepCalibration(fit, ...)
```

## Dependencies

- **InSilicoVA** - Requires rJava (Java JDK)
- **InterVA4** / **InterVA5**
- **Tariff**
- **nbc4va**
- **ggplot2** - Visualization

## Troubleshooting

### Java/rJava Issues
1. Check Java version: `java -version`
2. Match R and Java architecture (32-bit or 64-bit)
3. Reinstall rJava: `install.packages("rJava")`

### Check Installation Status
```r
openVA_status()  # Check all dependencies
openVA_update()  # Update packages
```

## References

- [openVA Website](https://openva.net/)
- [Package Vignette](https://cran.r-project.org/web/packages/openVA/vignettes/openVA-vignette.html)
- InterVA: Byass et al (2012, 2019)
- InSilicoVA: McCormick et al (2016)
- NBC: Miasnikof et al (2015)
- Tariff: James et al (2011)

## Available References

- `references/README.md` - Complete README with installation guide
- `references/file_structure.md` - Repository structure

---

**Generated by Skill Seeker** | Enhanced with Claude
