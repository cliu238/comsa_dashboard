# Reference: Known Issues and Solutions

## 1. Stan Model Compilation Issue (vacalibration)

### Problem
When running `vacalibration()`, you may encounter this error:

```
Error in prep_call_sampler(object) :
  the compiled object from C++ code for this model is invalid, possible reasons:
  - compiled with save_dso=FALSE;
  - compiled on a different platform;
  - does not exist (created from reading csv files).
```

### Cause
The vacalibration package ships with pre-compiled Stan models (`.rds` files) that were compiled on a different platform (e.g., Linux/x86) and are incompatible with your current system (e.g., macOS ARM64).

### Solution
Recompile the Stan models locally:

```r
library(rstan)

# Find vacalibration package location
pkg_path <- find.package('vacalibration')
stan_dir <- file.path(pkg_path, 'stan')

# Recompile seqcalib.stan
seqcalib <- stan_model(file.path(stan_dir, 'seqcalib.stan'))
saveRDS(seqcalib, file.path(stan_dir, 'seqcalib.rds'))

# Recompile seqcalib_mmat.stan
seqcalib_mmat <- stan_model(file.path(stan_dir, 'seqcalib_mmat.stan'))
saveRDS(seqcalib_mmat, file.path(stan_dir, 'seqcalib_mmat.rds'))
```

### Notes
- This recompilation only needs to be done once after installing vacalibration
- If you reinstall vacalibration, you'll need to recompile again
- Compilation may take a few minutes

### Docker Considerations

**If using Linux x86_64 base image**: The CRAN pre-compiled models are usually built on Linux x86_64, so they may work without recompilation.

**If using ARM64 base image** (e.g., for Apple Silicon): You'll still need to recompile.

**Recommended Dockerfile approach**: Compile during image build to ensure compatibility:

```dockerfile
# In Dockerfile, after installing vacalibration:
RUN R -e "
  library(rstan);
  pkg_path <- find.package('vacalibration');
  stan_dir <- file.path(pkg_path, 'stan');
  seqcalib <- stan_model(file.path(stan_dir, 'seqcalib.stan'));
  saveRDS(seqcalib, file.path(stan_dir, 'seqcalib.rds'));
  seqcalib_mmat <- stan_model(file.path(stan_dir, 'seqcalib_mmat.stan'));
  saveRDS(seqcalib_mmat, file.path(stan_dir, 'seqcalib_mmat.rds'));
"
```

This ensures the models are compiled for the exact environment where they'll run.
