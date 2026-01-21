# R Plumber Backend Dockerfile
# Trigger build for GitHub Container Registry
FROM rocker/r-ver:4.4

# Install system dependencies
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
    gcc \
    g++ \
    default-jdk \
    && rm -rf /var/lib/apt/lists/*

# Configure R to use Java - Fix linker paths for rJava
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV LD_LIBRARY_PATH=$JAVA_HOME/lib/server:$JAVA_HOME/lib:$LD_LIBRARY_PATH
ENV R_JAVA_LD_LIBRARY_PATH=$JAVA_HOME/lib/server
RUN R CMD javareconf

# Install R packages with error checking
RUN R -e "options(warn=2); install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres', 'pool'), repos='https://cloud.r-project.org')"

# Install rJava with proper Java configuration
RUN R -e "options(warn=2); install.packages('rJava', repos='https://cloud.r-project.org')"

# Install openVA and vacalibration packages
RUN R -e "options(warn=2); install.packages(c('openVA', 'vacalibration'), repos='https://cloud.r-project.org')"

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
