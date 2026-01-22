# WHO Verbal Autopsy Data Formats

## WHO 2016 Questionnaire Format

The WHO 2016 VA questionnaire provides standardized variable naming for verbal autopsy data collection. Variables follow a systematic naming convention for different sections and age groups.

## Variable Naming Convention

### Format: `idXXXXX`

- `id`: Identifier prefix for WHO variables
- `XXXXX`: 5-digit numeric code identifying the specific question

**Examples:**
- `id10104`: "Was baby moving, kicking or breathing at birth?"
- `id10019`: "What was the sex of the deceased?"
- `id10244`: "Did the limbs of the deceased become very thin during the illness?"

## Key Demographic Variables

### Stillbirth Indicators

**`id10104`** - Baby moving/kicking/breathing at birth:
- Values: `yes`, `no`, `dk` (don't know)
- Used to exclude stillbirths

**`id10109`** - Baby show signs of life:
- Values: `yes`, `no`, `dk`
- Used to exclude stillbirths

**`id10110`** - Baby born alive:
- Values: `yes`, `no`, `dk`
- Used to exclude stillbirths

**`id10114`** - Baby movement after birth:
- Values: `yes`, `no`, `dk`
- Additional stillbirth check

**Stillbirth Exclusion Logic:**
```r
Stillbirth <- ifelse(
  id10104 %in% c("no","dk") &
  id10109 %in% c("no","dk") &
  id10110 %in% c("no","dk"),
  1, 0
)
# Exclude: Stillbirth == 1
```

### Sex

**`id10019`** - Sex of deceased:
- Values: `male`, `female`, `ambiguous/intersex`
- Required for algorithm stratification (some algorithms differ by sex)

**Variable Splitting for Algorithms:**
```r
id10019a <- ifelse(id10019 == "male", "Y", "N")  # Male indicator
id10019b <- ifelse(id10019 == "female", "Y", "N")  # Female indicator
```

### Age Variables

Multiple age representations exist in WHO data. A unified `ageatdeath` field (in days) must be calculated.

**Age in Days:**
- `ageindays`: Direct age in days (all age groups)
- `ageindaysneonate`: Age in days (neonate-specific)
- `age_neonate_days`: Neonate age in days
- `age_child_days`: Child age in days

**Age in Months:**
- `ageinmonths`: Age in months (all age groups)
- `ageinmonthsbyyear`: Age in months calculated from years
- `age_child_months`: Child age in months

**Age in Years:**
- `ageinyears`: Age in years (all age groups)
- `ageinyears2`: Alternative years field
- `age_child_years`: Child age in years
- `age_adult`: Adult age in years

**Age in Minutes/Hours (Neonates):**
- `age_neonate_minutes`: Minutes since birth
- `age_neonate_hours`: Hours since birth

**Conversion Factors:**
- 1 month = 30.4 days
- 1 year = 365.25 days
- Minutes to days = minutes / (60 * 24)
- Hours to days = hours / 24

**Age Calculation Priority:**
```r
ageatdeath <- ageindays
if (is.na(ageatdeath) & isneonatal==1) {
  ageatdeath <- ageindaysneonate
  if (is.na(ageatdeath)) ageatdeath <- age_neonate_days
  if (is.na(ageatdeath)) ageatdeath <- age_neonate_hours / 24
  if (is.na(ageatdeath)) ageatdeath <- age_neonate_minutes / (60*24)
}
if (is.na(ageatdeath)) ageatdeath <- ageinmonths * 30.4
if (is.na(ageatdeath)) ageatdeath <- ageinyears * 365.25
# Continue with age_child_months, age_child_years, age_adult, etc.
```

### Age Group Flags

**`isneonatal`**: Binary flag (1 = neonate, 0 = not neonate)
- Neonate definition: 0-27 days

**`ischild`**: Binary flag (1 = child, 0 = not child)
- Child definition: 28 days to <5 years

**`isadult`**: Binary flag (1 = adult, 0 = not adult)
- Adult definition: ≥5 years

**Age Group Categories (for algorithms):**
- `id10022a`: Age ≥65 years (elderly)
- `id10022b`: Age 50-64 years
- `id10022c`: Age 15-49 years

### Season/Environment

**`id10004`** - Season of death:
- Values: `wet`, `dry`
- Some algorithms consider malaria risk by season

**Variable Splitting:**
```r
id10004a <- ifelse(id10004 == "wet", "Y", "N")  # Wet season
id10004b <- ifelse(id10004 == "dry", "Y", "N")  # Dry season
```

## Symptom Variables

Symptom variables are coded as binary or categorical responses.

### Binary Coding

**Standard Values:**
- `Y` or `yes` or `Yes` or `YES`: Symptom present
- `N` or `no` or `No` or `NO`: Symptom absent
- `.` or `DK` or `dk` or `Doesn't know` or `Refused to answer` or `ref` or `REF`: Unknown/missing

**Preprocessing Required:**
All variations must be standardized to `Y`, `N`, or `.` before running algorithms.

```r
for(i in 1:ncol(data)) {
  data[i][data[i] == "yes"] <- "Y"
  data[i][data[i] == "no"] <- "N"
  data[i][data[i] %in% c("DK","dk","Doesn't know","Don't know","ref","REF","Refused to answer")] <- "."
}
```

### Common Symptom Variables (Examples)

**Respiratory:**
- `id10244`: Limbs became very thin (malnutrition indicator)
- `id10249`: Swollen legs or feet (malnutrition/edema)
- Respiratory distress, cough, fast breathing variables (specific IDs vary)

**Gastrointestinal:**
- Diarrhea presence, duration, blood in stool
- Vomiting, abdominal pain

**Fever/Infection:**
- Fever presence and duration
- Convulsions
- Rash

**Neurological:**
- Convulsions
- Neck stiffness
- Loss of consciousness

**NOTE:** Complete symptom variable mapping requires WHO 2016 VA questionnaire codebook. The specific `idXXXXX` codes for each symptom vary by questionnaire section and age module.

## Interview Completion Status

**`q1311`** - Interview status:
- Value: `"Ready to get started"`: Interview completed
- Used to filter complete vs. incomplete interviews

**Quality Check:**
Complete interviews (`q1311 == "Ready to get started"`) should have valid `ageatdeath`. Cases with complete interviews but missing age may indicate data quality issues.

## Data Structure

### File Format

**CSV (Comma-Separated Values):**
- Standard format: `all_WHO.csv`
- Headers: Variable names (lowercase recommended)
- Rows: Individual VA cases (one case per row)
- Missing values: `NULL` or empty string (converted to `NA` in R)

**Loading in R:**
```r
data <- read.csv("all_WHO.csv",
                 stringsAsFactors = FALSE,
                 na.strings = c("NULL", ""))
names(data) <- tolower(colnames(data))  # Standardize to lowercase
```

### Data Dimensions

Typical WHO VA datasets contain:
- **Rows**: 100s to 10,000s of VA cases
- **Columns**: 300-500+ variables (depending on age modules included)

### Required Variables for openVA

Minimum required variables:
- Case ID (`ID` or `key`)
- Age at death (in days)
- Sex
- Age group flags (`isneonatal`, `ischild`, `isadult`)
- Symptom variables per WHO 2016 questionnaire

## Output Formats

### openVA Results (.Rdata)

openVA algorithms save results as R data files:

```r
save(InterVA5.neonate, InterVA5.child, InterVA5.adult,
     codeVAInsilico.neonate, codeVAInsilico.child, codeVAInsilico.adult,
     file = "openVA_results.Rdata")
```

**Objects Saved:**
- `InterVA5.neonate`, `InterVA5.child`, `InterVA5.adult`: InterVA5 result objects
- `codeVAInsilico.neonate`, `codeVAInsilico.child`, `codeVAInsilico.adult`: InSilicoVA result objects

**Accessing Results:**
```r
load("openVA_results.Rdata")

# Top causes
top_causes <- getTopCOD(InterVA5.neonate)

# Individual probabilities
indiv_probs <- getIndivProb(InterVA5.neonate)

# Population cause-specific mortality fractions
csmf <- getCSMF(InterVA5.neonate)
```

### EAVA Results (.csv)

EAVA typically outputs CSV files with hierarchical cause assignments:

```
ID, malnutrition1, malnutrition2, AIDS1, AIDS5, diarrhea8, ...
case001, 2, 2, 2, 2, 1, ...
case002, 1, 2, 2, 2, 2, ...
```

Values: `1` = cause criteria met, `2` = not met, `NA` = insufficient data

## Common Issues

### Encoding

- Ensure UTF-8 encoding for international characters
- Some WHO data may contain special characters in text fields

### Column Name Variations

- Lowercase vs. uppercase: Standardize with `tolower(colnames(data))`
- Spaces in names: Replace with underscores or convert to valid R names

### Missing Data

- Distinguish between "not asked" (NA) vs. "don't know" (`.`)
- openVA requires `.` for don't know responses, not `NA`

### Data Type Issues

- Age variables may be stored as character strings: Convert to numeric
- Binary variables stored as integers (0/1) instead of Y/N: Recode as needed

### Duplicate IDs

- Each case should have unique ID
- Check for and resolve duplicates before processing

## CHAMPS/MITS Data

For validation and calibration, CHAMPS provides:

**MITS (Minimally Invasive Tissue Sampling) Gold-Standard:**
- `mits_neonate_champs.csv`: Neonate MITS causes
- `mits_child_champs.csv`: Child MITS causes
- Format: Case ID + gold-standard cause classification

**Matched VA-MITS Data:**
- `CHAMPSVAdataMITSmatched_combined.csv`: VA cases with matched MITS diagnoses
- Enables validation of VA algorithm performance
- Used for training calibration models with vacalibration

**File Structure:**
```
ID, va_symptom1, va_symptom2, ..., mits_cause, mits_category
case001, Y, N, ..., Pneumonia, Respiratory
case002, N, Y, ..., Malaria, Infectious
```

## References

- WHO 2016 Verbal Autopsy Questionnaire: https://www.who.int/standards/classifications/other-classifications/verbal-autopsy-standards-ascertaining-and-attributing-causes-of-death-tool
- openVA R package documentation: https://cran.r-project.org/package=openVA
- CHAMPS project: https://champshealth.org/
