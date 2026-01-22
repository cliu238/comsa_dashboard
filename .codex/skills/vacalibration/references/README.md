
<!-- README.md is generated from README.Rmd. Please edit that file -->

# vacalibration

<!-- badges: start -->

<!-- badges: end -->

Given VA-only data for an age group, algorithm, and country, the package
calibrates population-level cause-specific mortality fractions (CSMFs)
produced by computer-coded verbal autopsy (CCVA) algorithms on
WHO-standardized verbal autopsy (VA) surveys. It also supports ensemble
calibration to accommodate multiple algorithms.

The package stores an inventory of uncertainty-quantified CCVA
misclassification matrices that are obtained using the framework of
[Pramanik et al. (2025)](https://doi.org/10.1214/24-AOAS2006) based on
data collected in the [CHAMPS project](https://champshealth.org/). The
inventory of 48 matrices covers three CCVA algorithms (EAVA, InSilicoVA,
InterVA), two age groups (neonates 0-27 days; children 1-59 months), and
eight countries (Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra
Leone, South Africa, plus an “other” for all other countries). See
[Pramanik et al. (2025+)](https://doi.org/10.1101/2025.07.02.25329250)
for analysis details.

More generally, this calibrates population-level prevalence derived from
single-class predictions of discrete classifiers. Users can provide
fixed or uncertainty-quantified misclassification matrices.

## Credit

[Sandipan Pramanik](https://sandypramanik.wixsite.com/sandy), Emily
Wilson, [Jacob Fiksel](https://jfiksel.github.io/), [Brian
Gilbert](https://scholar.google.com/citations?user=qu4Q1IEAAAAJ&hl=en),
[Abhirup Datta](https://abhidatta.com/)

## Funding Acknowledgement

Bill and Melinda Gates Foundation Grant (INV-034842); Johns Hopkins Data
Science and AI Institute; Eunice Kennedy Shriver National Institute of
Child Health K99 NIH Pathway to Independence Award (1K99HD114884-01A1).

## Installation

You can install the development version of `vacalibration` like so:

``` r
install.packages("vacalibration") # install
library(vacalibration) # load
```

## Example

In the following example, we demonstrate how `vacalibration()` can be
used to perform algorithm-specific and ensemble calibrations, and
generate calibrated CSMF estimates. For brevity, we exclude the
diagnostic and summary plots as well as the detailed output of the
posterior sampling.

### Algorithm-Specific Calibration

Below is an example of EAVA-specific VA-calibration for neonates in
Mozambique:

``` r
vacalib_eava = vacalibration(va_data = list("eava" = comsamoz_CCVAoutput$neonate$eava), 
                             age_group = "neonate", country = "Mozambique")

# CSMF
vacalib_eava$p_uncalib[1,]  # uncalibrated estimates
vacalib_eava$p_calib[1,,]  # posterior of calibrated estimates
vacalib_eava$pcalib_postsumm[1,,]  # posterior summary of calibrated estimates

# death counts
vacalib_eava$va_deaths_uncalib[1,]  # uncalibrated
vacalib_eava$va_deaths_calib_algo[1,]  # calibrated
```

InSilicoVA and InterVA-specific VA-calibration can be similarly
performed by replacing
`va_data = list("insilicova" = comsamoz_CCVAoutput$neonate$insilicova)`
and `va_data = list("interva" = comsamoz_CCVAoutput$neonate$interva)`.

Use `missmat_type` to control uncertainty propagation.
`missmat_type = "fixed"` calibrates using a fixed misclassification
matrix (by default, the average matrix in `CCVA_missmat`) and does not
propagate uncertainty. `missmat_type = "prior"` (package default) or
`missmat_type = "samples"` propagates uncertainty and is recommended.

To calibrate with posterior samples, use `missmat_type = "samples"` and
`missmat = CCVA_missmat$neonate$eava$postsamples$Mozambique` in the
example. Note: `CCVA_missmat` included in the package does not contain
posterior samples due to file size limits. If needed, obtain them from
the `CCVA_missmat` object in the [GitHub
repository](https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices)
and pass them to `vacalibration()`.

[Back to top](#top)

### Ensemble Calibration

To perform ensemble calibration, provide a list algorithm-specific CCVA
outputs. This performs both algorithm-specific calibration and an
ensemble calibration. Set `ensemble = FALSE` to turn off ensemble
calibration.

``` r
vacalib_ensemble = 
  vacalibration(va_data = list("eava" = comsamoz_CCVAoutput$neonate$eava,
                               "insilicova" = comsamoz_CCVAoutput$neonate$insilicova,
                               "interva" = comsamoz_CCVAoutput$neonate$interva),
                age_group = "neonate", country = "Mozambique")

# CSMF
vacalib_ensemble$p_uncalib  # uncalibrated estimates

# posterior of calibrated CSMF
vacalib_ensemble$p_calib["eava",,]  # EAVA
vacalib_ensemble$p_calib["insilicova",,]  # InSilicoVA
vacalib_ensemble$p_calib["interva",,]  # InterVA
vacalib_ensemble$p_calib["ensemble",,]  # ensemble

# posterior summary of calibrated CSMF
vacalib_ensemble$pcalib_postsumm["eava",,]  # EAVA
vacalib_ensemble$pcalib_postsumm["insilicova",,]  # InSilicoVA
vacalib_ensemble$pcalib_postsumm["interva",,]  # InterVA
vacalib_ensemble$pcalib_postsumm["ensemble",,]  # ensemble

# death counts
vacalib_ensemble$va_deaths_uncalib  # uncalibrated
vacalib_ensemble$va_deaths_calib_algo  # calibrated counts based on algorithm-specific calibration
vacalib_ensemble$va_deaths_calib_ensemble  # calibrated counts based on ensemble calibration
```

If `missmat` includes user-specified matrices, then `age_group` and
`country` are not required.

Calibration for children can be performed similarly.

[Back to top](#top)

## Calibration for Causes Outside CHAMPS Broad Causes

As discussed in [CCVA Misclassification Matrices](#sec-CCVA_missmat),
the matrices in `CCVA_missmat` are available for CHAMPS broad causes. In
cases where the causes in `va_data` are not a subset of the CHAMPS broad
causes, a cause-mapping step is required. One such application is the
[CA CODE](https://childmortality.org/about) project, which compiles
VA-based death counts across multiple countries. For example, a study in
Bangladesh analyzed 302 neonatal deaths using EAVA, and reported 82
deaths due to *Intrapartum*, 17 due to *Congenital*, 6 due to
*Diarrhoeal*, 33 due to *LRI*, 108 due to *Sepsis*, 35 due to *Preterm*,
14 due to *Tetanus*, and 7 due to *Other*.

In such cases, `vacalibration()` requires specifying `studycause_map`, a
mapping from the study causes to the CHAMPS broad causes. For this
example, following expert guidance, we define:

``` r
set_studycause_map = c("Intrapartum" = "ipre", "Congenital" = "congenital_malformation",
                       "Diarrhoeal" = "sepsis_meningitis_inf", "LRI" = "pneumonia",
                       "Sepsis" = "sepsis_meningitis_inf", "Preterm" = "prematurity", 
                       "Tetanus" = "sepsis_meningitis_inf", "Other" = "other")
```

This mapping converts the misclassification matrices in `CCVA_missmat`
to align with the study causes, enabling VA-calibration. This can then
be implemented as:

``` r


vacalib_cacode = vacalibration(va_data = list("eava" = c("Intrapartum" = 82, "Congenital" = 17,
                                                         "Diarrhoeal" = 6, "LRI" = 33,
                                                         "Sepsis" = 108, "Preterm" = 35, 
                                                         "Tetanus" = 14, "Other" = 7)), 
                               age_group = "neonate", country = "Bangladesh",
                               studycause_map = set_studycause_map)

# CSMF
vacalib_cacode$p_uncalib[1,]  # uncalibrated estimates
vacalib_cacode$p_calib[1,,]  # posterior of calibrated estimates
vacalib_cacode$pcalib_postsumm[1,,]  # posterior summary of calibrated estimates

# death counts
vacalib_cacode$va_deaths_uncalib[1,]  # uncalibrated
vacalib_cacode$va_deaths_calib_algo[1,]  # calibrated
```

This is required only when using the misclassification matrices from
`CCVA_missmat`. If `missmat` includes user-specified matrices, then
`age_group`, `country`, and `studycause_map` are not required.

[Back to top](#top)
