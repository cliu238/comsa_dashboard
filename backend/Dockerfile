# R Plumber Backend Dockerfile
# Trigger build for GitHub Container Registry
# Base image pinned to the rocker/r-ver:4.4 multi-arch OCI index digest,
# resolved from the registry on 2026-08-25. That image is R 4.4.3. The
# digest is the multi-arch INDEX (covers both linux/amd64, used by the CI
# runner, and linux/arm64, used for local dev) rather than a single-arch
# digest, so both keep resolving from the same pin.
FROM rocker/r-ver:4.4@sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c

# Install system dependencies
# cmake is required by RcppParallel (a transitive dependency of openVA/EAVA), which
# began requiring cmake >= 3.5 in a release between 2026-07-28 and 2026-08-12. The R
# packages were unpinned at the time, so this surfaced as a build failure on the first
# backend deploy after that upstream change (#122). They are pinned now -- see the
# CRAN_SNAPSHOT block below -- so that specific recurrence is closed.
#
# KNOWN LIMITATION (issue #123 follow-up): this apt layer is still unpinned. No
# version constraints, no snapshot -- `apt-get update` resolves Ubuntu noble live, so
# a cache-free rebuild (the very path `force_backend_rebuild` uses to PROVE
# reproducibility) can pick up different system libraries than the previous build.
# /opt/package-manifest.csv records installed.packages() only, so the CI manifest diff
# cannot see that drift. Same failure class as #122, moved from CRAN to apt. Pinning
# it needs a snapshot.ubuntu.com source and its own verification pass.
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpq-dev \
    libsodium-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libpcre2-dev \
    libdeflate-dev \
    make \
    cmake \
    gcc \
    g++ \
    default-jdk \
    && rm -rf /var/lib/apt/lists/*

# Configure R to use Java - Fix linker paths for rJava
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV LD_LIBRARY_PATH=$JAVA_HOME/lib/server:$JAVA_HOME/lib:$LD_LIBRARY_PATH
ENV R_JAVA_LD_LIBRARY_PATH=$JAVA_HOME/lib/server
RUN R CMD javareconf

# Single source of truth for the CRAN snapshot date used by every
# install.packages() call below. The base image's own default repo is the
# 2025-04-10 snapshot, which does NOT carry vacalibration or EAVA -- if this
# override is ever lost, the build FAILS loudly on those two packages rather
# than silently installing different versions from a different snapshot.
ENV CRAN_SNAPSHOT=https://p3m.dev/cran/__linux__/noble/2026-08-01

# Append (never overwrite) the snapshot repo onto the base image's own
# Rprofile.site. The base image's Rprofile.site also sets HTTPUserAgent
# (which is what makes p3m.dev serve prebuilt binaries instead of source
# tarballs) and download.file.method='libcurl'; both must survive, so this
# must be `>>`, not `>`.
RUN echo "options(repos = c(CRAN = \"${CRAN_SNAPSHOT}\"))" >> /usr/local/lib/R/etc/Rprofile.site

# sodium is used by backend/auth/passwords.R via sodium::password_store() /
# password_verify() but was never installed explicitly -- it arrived
# transitively via plumber. libsodium-dev in the apt block is the system
# library, not the R package. If the transitive edge disappears upstream,
# authentication breaks at runtime on the first login while the build stays
# green.
# Install R packages with error checking
RUN R -e "options(warn=2); install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres', 'pool', 'jose', 'sodium'))"

# Install rJava with proper Java configuration
RUN R -e "options(warn=2); install.packages('rJava')"

# Install openVA, EAVA, and vacalibration packages
# EAVA is only Suggests'd by openVA — must be installed explicitly
# knitr is Suggests'd by vacalibration but required at runtime in v2.2
RUN R -e "options(warn=2); install.packages(c('openVA', 'EAVA', 'vacalibration', 'knitr'))"

# Recompile Stan models for current platform to fix cross-platform compatibility
# The vacalibration package ships with pre-compiled models from CRAN that may not work correctly
# We compile from source .stan files and overwrite the bundled .rds files
RUN R -e "library(rstan); \
  options(mc.cores = 1); \
  pkg_path <- find.package('vacalibration'); \
  stan_dir <- file.path(pkg_path, 'stan'); \
  \
  message('=== Compiling Stan models for vacalibration ==='); \
  message(paste('Platform:', R.version.string)); \
  message(paste('Package path:', pkg_path)); \
  \
  message('[1/2] Compiling seqcalib.stan...'); \
  t_start <- Sys.time(); \
  seqcalib <- stan_model(file.path(stan_dir, 'seqcalib.stan')); \
  saveRDS(seqcalib, file.path(stan_dir, 'seqcalib.rds')); \
  t_end <- Sys.time(); \
  message(sprintf('Compiled in %.1f seconds', as.numeric(t_end - t_start))); \
  \
  message('[2/2] Compiling seqcalib_mmat.stan...'); \
  t_start <- Sys.time(); \
  seqcalib_mmat <- stan_model(file.path(stan_dir, 'seqcalib_mmat.stan')); \
  saveRDS(seqcalib_mmat, file.path(stan_dir, 'seqcalib_mmat.rds')); \
  t_end <- Sys.time(); \
  message(sprintf('Compiled in %.1f seconds', as.numeric(t_end - t_start))); \
  \
  message('=== Stan model compilation complete ===');"

# Write a machine-readable manifest of every installed R package and its
# version. .github/workflows/deploy.yml extracts this file from the built
# image and diffs it against the committed backend/package-manifest.csv,
# which is what makes "the same package versions every build" checkable
# rather than assumed. Placed before COPY so a build failure here still
# cannot have been caused by an application source change.
RUN R -e "\
  Sys.setlocale('LC_COLLATE', 'C'); \
  pkgs <- as.data.frame(installed.packages()[, c('Package', 'Version')], stringsAsFactors = FALSE); \
  required <- c('sodium', 'vacalibration', 'EAVA', 'openVA', 'knitr', 'rstan', 'RcppParallel', 'plumber', 'jose', 'pool', 'RPostgres', 'rJava', 'uuid', 'future', 'jsonlite'); \
  stopifnot('sodium' %in% pkgs\$Package, all(required %in% pkgs\$Package)); \
  pkgs <- pkgs[order(pkgs\$Package), ]; \
  write.csv(pkgs, '/opt/package-manifest.csv', row.names = FALSE, quote = FALSE)"

# Create app directory
WORKDIR /app

# Copy backend code
COPY backend/ /app/

# Create data directories
RUN mkdir -p /app/data/uploads /app/data/outputs

# Create non-root user and set permissions
RUN groupadd -r appuser -g 1000 && \
    useradd -r -u 1000 -g appuser appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Run the plumber API
CMD ["Rscript", "run.R"]
