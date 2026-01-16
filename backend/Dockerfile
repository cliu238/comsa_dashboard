# R Plumber Backend Dockerfile
FROM rocker/r-ver:4.4

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres'), repos='https://cloud.r-project.org')"
RUN R -e "install.packages(c('openVA', 'vacalibration'), repos='https://cloud.r-project.org')"

# Create app directory
WORKDIR /app

# Copy backend code
COPY backend/ /app/

# Create data directories
RUN mkdir -p /app/data/uploads /app/data/outputs

# Expose port
EXPOSE 8000

# Run the plumber API
CMD ["Rscript", "run.R"]
