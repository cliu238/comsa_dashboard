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
    && rm -rf /var/lib/apt/lists/*

# Install R packages with error checking
RUN R -e "options(warn=2); install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres'), repos='https://cloud.r-project.org')"
RUN R -e "options(warn=2); install.packages(c('openVA', 'vacalibration'), repos='https://cloud.r-project.org')"

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
