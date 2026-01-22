---
name: va-pipeline
description: Process verbal autopsy data using openVA and EAVA algorithms to classify causes of death. This skill should be used when working with WHO-format verbal autopsy data, running InterVA/InSilicoVA algorithms, or preparing data for calibration with vacalibration. Trigger this skill when users mention VA data processing, openVA, EAVA, or cause-of-death classification tasks.
---

# Verbal Autopsy Data Processing Pipeline

## Overview

Process verbal autopsy (VA) data to classify causes of death using openVA algorithms (InterVA5, InSilicoVA) and Expert Algorithm for Verbal Autopsy (EAVA). This skill provides workflows for transforming raw VA data into formats suitable for algorithmic classification and subsequent calibration.

## Core Concepts

### Verbal Autopsy Data
Verbal autopsy collects information about symptoms and circumstances surrounding a death through structured interviews. The WHO provides standardized questionnaires that capture:
- Demographic information (age, sex, location)
- Symptoms experienced during fatal illness
- Timeline of symptom onset
- Medical history and treatment sought

### Age Groups
VA algorithms process three distinct age groups separately:
- **Neonates**: 0-27 days
- **Children (1-59 months)**: 28 days to <5 years
- **Adults**: 5+ years (including children 5+ and adults)

### Algorithms

**openVA Package:**
- `InterVA5`: Rule-based probabilistic algorithm using expert-derived conditional probabilities
- `InSilicoVA`: Bayesian algorithm that learns from data patterns

**EAVA (Expert Algorithm for Verbal Autopsy):**
- Rule-based algorithm using expert-defined hierarchical criteria
- Separate implementations for neonates and children (1-59 months)
- Uses specific symptom combinations and timing to classify causes

## Data Requirements

### Input Data Format

**WHO-format CSV files** with standardized variable names:
- Variables follow WHO 2016 VA questionnaire naming (e.g., `id10104`, `id10019`, `id10022`)
- Required demographic variables: age at death, sex, location
- Binary symptom variables coded as: `Y` (yes), `N` (no), `.` (don't know/missing)

**Key variables:**
- `id10104`, `id10109`, `id10110`: Stillbirth indicators (exclude stillbirths from analysis)
- `id10019`: Sex (male/female)
- `id10022`: Age group category
- `ageatdeath`: Age at death in days (calculated from various age fields)
- `isneonatal`, `ischild`, `isadult`: Age group flags

### Data Preprocessing Steps

**Age Calculation:**
Convert various age representations into a single `ageatdeath` field in days:
```r
# Priority order for age calculation:
1. ageindays (direct days)
2. ageindaysneonate (for neonates)
3. ageinmonths * 30.4
4. ageinyears * 365.25
5. age_neonate_days, age_child_months, age_child_years (by age group)
```

**Binary Recoding:**
Standardize response values across all columns:
- `yes/Yes/YES` → `Y`
- `no/No/NO` → `N`
- `DK/dk/Doesn't know/Don't know/Refused to answer/ref/REF` → `.`

**Variable Mapping:**
Some WHO variables need splitting for algorithm compatibility:
- `id10004` (wet/dry season) → `id10004a` (wet: Y/N), `id10004b` (dry: Y/N)
- `id10019` (sex) → `id10019a` (male: Y/N), `id10019b` (female: Y/N)

**Exclusions:**
- Remove stillbirths: `id10104="no" & id10109="no" & id10110="no"`
- Filter by age group for algorithm-specific processing

## Workflow: Processing VA Data

### Step 1: Prepare WHO-Format Data

Load and clean raw VA data:
```r
library(openVA)
library(CrossVA)

# Load data
data <- read.csv("path/to/all_WHO.csv", stringsAsFactors = FALSE, na.strings=c("NULL",""))
names(data) <- tolower(colnames(data))

# Remove stillbirths
data$Stillbirth <- ifelse(
  data$id10104 %in% c("no","dk") &
  data$id10109 %in% c("no","dk") &
  data$id10110 %in% c("no","dk"), 1, 0
)
data <- data[data$Stillbirth != 1, ]

# Standardize binary coding (loop through all columns)
for(i in 1:ncol(data)) {
  data[i][data[i] == "yes"] <- "Y"
  data[i][data[i] == "no"] <- "N"
  data[i][data[i] %in% c("DK","dk","ref","Refused to answer")] <- "."
}

# Calculate unified age at death in days
data$ageatdeath <- data$ageindays
data$ageatdeath <- ifelse(is.na(data$ageatdeath) & !is.na(data$ageindaysneonate) & data$isneonatal==1,
                          data$ageindaysneonate, data$ageatdeath)
data$ageatdeath <- ifelse(is.na(data$ageatdeath) & !is.na(data$ageinmonths),
                          data$ageinmonths*30.4, data$ageatdeath)
# ... continue for other age fields
```

### Step 2: Run openVA Algorithms

**Split by age group and run algorithms:**

```r
# Neonates (0-27 days)
data.neonate <- subset(data, isneonatal == 1)

InterVA5.neonate <- codeVA(
  data = data.neonate,
  data.type = "WHO2016",
  model = "InterVA5",
  version = "5.0",
  HIV = "l",
  Malaria = "l"
)

codeVAInsilico.neonate <- codeVA(
  data = data.neonate,
  data.type = "WHO2016",
  model = "InSilicoVA",
  Nsim = 10000,
  auto.length = TRUE
)

# Children (28 days - 59 months)
data.child <- subset(data, ischild == 1 & ageatdeath >= 28 & ageatdeath < 60*30.4)

InterVA5.child <- codeVA(
  data = data.child,
  data.type = "WHO2016",
  model = "InterVA5",
  version = "5.0",
  HIV = "l",
  Malaria = "l"
)

codeVAInsilico.child <- codeVA(
  data = data.child,
  data.type = "WHO2016",
  model = "InSilicoVA",
  Nsim = 10000,
  auto.length = TRUE
)

# Save results
save(InterVA5.neonate, InterVA5.child,
     codeVAInsilico.neonate, codeVAInsilico.child,
     file = "openVA_results.Rdata")
```

### Step 3: Extract Individual Probabilities

For calibration with vacalibration, extract individual-level cause probabilities:

```r
# Load results
load("openVA_results.Rdata")

# InterVA probabilities - Neonate
interva_probs_neonate <- getIndivProb(InterVA5.neonate)
interva_probs_neonate[interva_probs_neonate == 0] <- .0000001
interva_probs_neonate <- t(apply(interva_probs_neonate, 1, function(x) (x/sum(x))))

# InSilicoVA probabilities - Neonate
insilico_probs_neonate <- getIndivProb(codeVAInsilico.neonate)
insilico_probs_neonate[insilico_probs_neonate == 0] <- .0000001
insilico_probs_neonate <- t(apply(insilico_probs_neonate, 1, function(x) (x/sum(x))))

# Repeat for child age group
# ...
```

### Step 4: Run EAVA Algorithms

EAVA uses expert-defined hierarchical rules. The reference file `references/eava_workflow.md` contains detailed variable mappings.

**Basic EAVA structure for children (1-59 months):**

```r
# Prepare EAVA matrix
varlist <- c("malnutrition1", "malnutrition2", "AIDS1", "AIDS5",
             "diarrhea8", "dysentery8", "pneumoniafb2daysgr",
             "malaria251", "measles4", "meningitis", "pertussis",
             "sepsis_nomal251", "injury", "congmalf2", "preterm_all_mo")

EAVA <- as.data.frame(matrix(data=NA, nrow=nrow(data.child), ncol=length(varlist)))
names(EAVA) <- varlist
EAVA <- cbind(data.child$ID, EAVA)

# Apply hierarchical rules (examples)
# Malnutrition1: Limbs became very thin OR swollen legs/feet
EAVA$malnutrition1 <- ifelse(
  data.child$id10244 == "yes" | data.child$id10249 == "yes", 1, 2
)

# Diarrhea8: Diarrhea lasting >=2 weeks
EAVA$diarrhea8 <- ifelse(
  data.child$diarrhea_duration >= 14, 1, 2
)

# ... apply remaining rules per EAVA specification
```

See `references/eava_workflow.md` for complete variable definitions and hierarchical rules.

### Step 5: Create Cause Mappings for Calibration

Map algorithm-specific causes to standardized broad categories:

```r
# Example for neonates
causes_neonate <- c("congenital_malformation", "pneumonia",
                   "sepsis_meningitis_inf", "ipre", "other", "prematurity")

cause_map_neonate <- data.frame(
  causes = c("Congenital malformation",
            "Neonatal pneumonia", "Acute resp infect incl pneumonia",
            "Neonatal sepsis", "Meningitis and encephalitis", "Sepsis (non-obstetric)",
            "Birth asphyxia",
            "Prematurity"),
  broad_cause = c("congenital_malformation",
                 "pneumonia", "pneumonia",
                 "sepsis_meningitis_inf", "sepsis_meningitis_inf", "sepsis_meningitis_inf",
                 "ipre",
                 "prematurity")
)

# Use for aggregating probabilities by broad cause
```

## Integration with vacalibration

After running openVA and EAVA, the individual-level probabilities can be used with the `vacalibration` package for Bayesian calibration against gold-standard causes of death (e.g., from MITS - Minimally Invasive Tissue Sampling).

**Typical calibration workflow:**
1. Process VA data through openVA/EAVA to get individual probabilities
2. Match VA cases to gold-standard causes (MITS/clinical diagnoses)
3. Use `vacalibration` to estimate calibrated cause-specific mortality fractions
4. Apply calibration to new VA data for improved accuracy

## Common Data Sources

Based on the reference repository:

**COMSA (Child Mortality Surveillance in Africa):**
- WHO-format VA data: `all_WHO.csv`
- Includes demographic and symptom variables
- Age groups: neonates, children, adults

**CHAMPS (Child Health and Mortality Prevention Surveillance):**
- VA data matched with MITS gold-standard: `CHAMPSVAdataMITSmatched_combined.csv`
- Used for validation and calibration
- openVA format: `CHAMPSVAdata_openVA_fmt.csv`

**Output files:**
- openVA results: `openVA_comsa.Rdata`, `openVA_champs.Rdata`
- EAVA results: `eava_child_comsa.csv`, `eava_neonate_comsa.csv`
- MITS causes for calibration: `mits_child_champs.csv`, `mits_neonate_champs.csv`

## Key R Packages

Ensure these packages are installed:
```r
install.packages("openVA")
install.packages("CrossVA")
install.packages("InSilicoVA")
install.packages("data.table")
install.packages("haven")  # For reading Stata .dta files if needed
```

## Troubleshooting

**Missing age data:**
- Check all age-related fields: `ageindays`, `ageindaysneonate`, `ageinmonths`, `ageinyears`, age-group-specific fields
- Some incomplete interviews may lack age information

**Stillbirth classification:**
- Always exclude stillbirths before running VA algorithms
- Check combinations of `id10104`, `id10109`, `id10110`

**Binary coding issues:**
- Ensure all Y/N/. coding is standardized before running algorithms
- openVA expects specific formats and will fail with inconsistent coding

**Algorithm-specific cause lists:**
- InterVA5 and InSilicoVA may return different cause lists
- Ensure cause mapping accounts for all possible causes from both algorithms
- Zero probabilities should be replaced with small values (.0000001) for calibration

## Resources

### references/
- `eava_workflow.md`: Complete EAVA variable definitions and hierarchical rules for neonates and children
- `data_formats.md`: Detailed WHO variable naming conventions and expected formats

### Example Repository
The skill is based on: https://github.com/emilybrownwilson/Raw_to_CalibratedVA_input_pipeline
