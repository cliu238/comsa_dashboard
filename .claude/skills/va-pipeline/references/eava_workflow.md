# EAVA (Expert Algorithm for Verbal Autopsy) Workflow

## Overview

EAVA is a hierarchical rule-based algorithm for classifying causes of death from verbal autopsy data. Rules are applied in a specific order, with each cause checked sequentially. Once a case matches a cause definition, it is classified and no further rules are evaluated.

## Hierarchy

EAVA applies causes in order from most specific to least specific. The hierarchical structure ensures that distinctive symptom patterns are captured before more general classifications.

## Age-Specific Implementations

### Neonates (0-27 days)

The EAVA neonate algorithm evaluates causes in this order:

1. **Congenital malformations** (`congmalf2`)
2. **Pneumonia** (`pneumoniafb2daysgr`)
3. **Sepsis/Meningitis/Infections** (`sepsis_nomal251`, `meningitis`)
4. **Intrapartum-related events (Birth asphyxia)** (`ipre`, `bi5ba5`, `ba5`)
5. **Prematurity** (`preterm_all_mo`)
6. **Other** (residual category)

### Children (1-59 months)

The EAVA child algorithm evaluates causes in this order:

1. **Severe malnutrition** (`malnutrition2`, then `malnutrition1` as residual)
2. **HIV/AIDS** (`AIDS5`, then `AIDS1` as residual)
3. **Diarrhea** (`diarrhea8`, `dysentery8`, `diardysn8`)
4. **Malaria** (`malaria251`, `malaria_possible`)
5. **Measles** (`measles4`)
6. **Meningitis** (`meningitis`)
7. **Pertussis** (`pertussis`)
8. **Pneumonia** (`pneumoniafb2daysgr`, `possibleari3`)
9. **Sepsis** (`sepsis_nomal251`)
10. **Injury** (`injury`, `injury3_slide15_4`)
11. **Congenital malformation** (`congmalf2`)
12. **Other infections** (`residual_infect_slide15_4`)
13. **Other** (residual category)

## Variable Definitions - Children (1-59 months)

### Malnutrition

**`malnutrition1`** (Residual malnutrition):
- Placed at the bottom of the hierarchy
- **Definition**: Limbs became very thin during the fatal illness OR had swollen legs or feet during the illness
- **Mapping**: `id10244 == "yes"` OR `id10249 == "yes"` → 1, else 2

**`malnutrition2`** (Primary malnutrition):
- **Definition**: Same symptoms as malnutrition1, AND one of these was the first symptom of the illness
- **Note**: Requires sequential analysis (SA) data on order of symptom appearance
- If SA data unavailable, use modified algorithm based on symptom presence only

### HIV/AIDS

**`AIDS1`** (Residual AIDS):
- **Definition**: Known HIV positive status
- **Mapping**: `hiv_status == "positive"` → 1, else 2

**`AIDS5`** (Primary AIDS):
- **Definition**: Known HIV positive AND specific AIDS-related symptoms (wasting, opportunistic infections, etc.)
- **Requires**: Multiple symptom combinations indicative of advanced AIDS

### Diarrhea & Dysentery

**`diarrhea8`**:
- **Definition**: Diarrhea lasting ≥2 weeks (≥14 days)
- **Mapping**: `diarrhea_duration >= 14` → 1, else 2

**`dysentery8`**:
- **Definition**: Bloody diarrhea lasting ≥2 weeks
- **Mapping**: `bloody_diarrhea == "yes"` AND `diarrhea_duration >= 14` → 1, else 2

**`diardysn8`**:
- **Definition**: Combined diarrhea/dysentery lasting ≥2 weeks
- Captures cases with both symptoms

**`possiblediar8_4`**, **`possibledysn8_4`**, **`possdiardysn8_4`**:
- Modified definitions for cases with incomplete duration data

### Malaria

**`malaria251`**:
- **Definition**: Fever + malaria-endemic area + specific symptom combinations
- **Mapping**: Multiple criteria including fever duration, convulsions, anemia

**`malaria_possible`**:
- **Definition**: Fever + endemic area with fewer confirmatory symptoms
- Used when `malaria251` doesn't match but malaria is plausible

### Measles

**`measles4`**:
- **Definition**: Rash + fever + at least one of: cough, red eyes, runny nose
- **Duration**: Symptoms must occur in characteristic sequence
- **Mapping**: Specific WHO variable combinations for measles syndrome

### Meningitis

**`meningitis`**:
- **Definition**: Fever + neck stiffness OR bulging fontanelle (for infants)
- **May include**: Convulsions, altered consciousness
- **Mapping**: `neck_stiffness == "yes"` OR `bulging_fontanelle == "yes"` with fever

### Pertussis

**`pertussis`**:
- **Definition**: Cough lasting ≥2 weeks + whooping sound
- **May include**: Post-cough vomiting, cyanosis
- **Mapping**: WHO variables for characteristic pertussis cough

### Pneumonia

**`pneumoniafb2daysgr`**:
- **Definition**: Fever + fast/difficult breathing for ≥2 days
- **Severity markers**: Chest indrawing, inability to feed/drink
- **Mapping**: Multiple respiratory symptom combinations

**`possibleari3`**:
- **Definition**: Acute respiratory infection with fewer confirmatory criteria
- Used when full pneumonia criteria not met

### Sepsis

**`sepsis_nomal251`**:
- **Definition**: Systemic infection without malaria
- **Symptoms**: Fever + multiple organ involvement
- **Excludes**: Cases already classified as malaria251

### Injury

**`injury`**:
- **Definition**: External cause of death (accident, violence)
- **Types**: Drowning, falls, burns, poisoning, road traffic accidents, violence

**`injury3_slide15_4`**:
- Modified injury definition for specific coding scenarios

### Congenital Malformation

**`congmalf2`**:
- **Definition**: Birth defects or congenital abnormalities
- **May be**: Visible malformations or organ defects
- **Timing**: Usually apparent from birth or shortly after

### Residual Infections

**`residual_infect_slide15_4`**:
- **Definition**: Infectious disease not captured by specific categories above
- Includes rare or unspecified infections

## Variable Definitions - Neonates (0-27 days)

### Congenital Malformation

**`congmalf2`**:
- Same as child definition
- Higher priority in neonate hierarchy

### Pneumonia

**`pneumoniafb2daysgr`**:
- **Definition**: Fast/difficult breathing in first 28 days of life
- **May include**: Grunting, chest indrawing, inability to feed
- **Note**: Neonatal pneumonia presentation differs from older children

### Sepsis & Meningitis

**`sepsis_nomal251`**:
- **Definition**: Neonatal sepsis signs - fever/hypothermia, poor feeding, lethargy
- **Risk factors**: Maternal fever, prolonged rupture of membranes

**`meningitis`**:
- Similar to child definition but includes bulging fontanelle as primary sign

### Intrapartum-Related Events

**`ipre`** (Intrapartum-related events):
- **Definition**: Birth asphyxia, difficulties during delivery
- **Symptoms**: Failure to cry at birth, resuscitation needed

**`bi5ba5`**:
- **Definition**: Birth injury or birth asphyxia with specific criteria

**`ba5`**:
- **Definition**: Birth asphyxia alone

### Prematurity

**`preterm_all_mo`**:
- **Definition**: Born preterm (<37 weeks gestation) with associated complications
- **Signs**: Low birth weight, difficulty breathing, temperature regulation issues
- **Note**: May overlap with other conditions; hierarchy determines final classification

## Coding Guidelines

### Binary Coding

All EAVA variables are coded as:
- `1` = Cause criteria met (YES)
- `2` = Cause criteria not met (NO)
- `NA` = Insufficient data to determine

### Hierarchical Application

Apply rules in order:
1. Start with highest-priority cause
2. Check if case meets all criteria
3. If YES, assign that cause and stop
4. If NO, move to next cause in hierarchy
5. Continue until a match is found
6. Cases matching no specific cause → "Other"

### Missing Data Handling

- If key variables are missing for a cause definition, that cause cannot be assigned
- Move to next cause in hierarchy
- Document missing data patterns for quality assessment

## Implementation Notes

### Data Quality

- EAVA performance depends on complete and accurate symptom data
- Review missingness patterns before running algorithm
- High missingness may require imputation or modified criteria

### Age Boundaries

- Strictly enforce age cutoffs (neonates: 0-27 days; children: 28 days-59 months)
- Age misclassification can lead to wrong algorithm application

### Multiple Conditions

- EAVA assigns a single primary cause
- Real cases may have multiple contributing causes
- Hierarchy determines which is captured as primary

### Validation

- When gold-standard data available (MITS, clinical diagnoses), compare EAVA output
- Calculate sensitivity/specificity for each cause
- Use results to inform calibration with vacalibration package

## Reference

Based on the expert algorithm specifications from the COMSA and CHAMPS projects. Variable mappings align with WHO 2016 verbal autopsy questionnaire.
