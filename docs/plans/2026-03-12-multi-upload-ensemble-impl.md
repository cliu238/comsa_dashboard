# Multi-Upload Ensemble Calibration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Support uploading separate VA data files per algorithm for ensemble calibration, with dynamic upload rows and per-file algorithm selection.

**Architecture:** Frontend replaces single file input with dynamic upload rows (algorithm dropdown + file picker per row) when ensemble is checked for vacalibration jobs. Pipeline ensemble uses single file + multi-select checkboxes (openVA fans out per algorithm). Backend accepts multi-keyed file fields and stores per-algorithm CSVs.

**Tech Stack:** React (frontend), R plumber (backend), vitest (frontend tests), R test assertions (backend tests)

---

### Task 1: Frontend — Add `uploads` state and ensemble-aware upload UI

**Files:**
- Modify: `frontend/src/components/JobForm.jsx`

**Step 1: Write failing tests for the new upload row behavior**

Add to `frontend/src/components/JobForm.test.js`:

```js
describe('Multi-upload ensemble UI (issue #27)', () => {
  it('has uploads state array for managing per-algorithm files', () => {
    expect(jobFormSrc).toContain('useState([{ algorithm:');
  })

  it('shows upload rows when ensemble is checked for vacalibration', () => {
    // The upload-row class should exist for per-algorithm file inputs
    expect(jobFormSrc).toContain('upload-row')
  })

  it('has add-algorithm button capped at 3 rows', () => {
    expect(jobFormSrc).toContain('Add Algorithm')
    // Max 3 algorithms exist, so cap at 3
    expect(jobFormSrc).toContain('uploads.length < 3')
  })

  it('has remove button for upload rows', () => {
    expect(jobFormSrc).toContain('removeUpload')
  })

  it('filters already-selected algorithms from dropdowns', () => {
    // Each dropdown should exclude algorithms already chosen in other rows
    expect(jobFormSrc).toContain('availableAlgorithms')
  })

  it('keeps single file input for non-ensemble vacalibration', () => {
    // Non-ensemble still has the per-row algorithm dropdown
    expect(jobFormSrc).toContain("type=\"file\"")
  })

  it('pipeline ensemble shows checkboxes + single file (no per-algo uploads)', () => {
    // Pipeline ensemble uses existing checkbox UI, not upload rows
    // The single file input should remain for pipeline
    expect(jobFormSrc).toContain('algorithm-checkboxes')
  })
})
```

**Step 2: Run tests to verify they fail**

Run: `cd frontend && npm test -- --run`
Expected: FAIL — `uploads` state, `upload-row`, `Add Algorithm`, `removeUpload`, `availableAlgorithms` not found in source

**Step 3: Implement the upload rows UI in JobForm.jsx**

Replace the single `file` state (line 11) with an `uploads` array:

```js
// Replace: const [file, setFile] = useState(null);
// With:
const [uploads, setUploads] = useState([{ algorithm: '', file: null }]);
```

Add helper functions after `handleAlgorithmSelect` (after line 88):

```js
const addUpload = () => {
  if (uploads.length < 3) {
    setUploads(prev => [...prev, { algorithm: '', file: null }]);
  }
};

const removeUpload = (index) => {
  if (uploads.length > 2) {
    setUploads(prev => prev.filter((_, i) => i !== index));
  }
};

const updateUpload = (index, field, value) => {
  setUploads(prev => prev.map((u, i) => i === index ? { ...u, [field]: value } : u));
};

const availableAlgorithms = (currentIndex) => {
  const selected = uploads
    .filter((_, i) => i !== currentIndex)
    .map(u => u.algorithm)
    .filter(Boolean);
  return ['InterVA', 'InSilicoVA', 'EAVA'].filter(a => !selected.includes(a));
};
```

When ensemble is toggled on for vacalibration, initialize 2 upload rows:

```js
// In the useEffect that syncs algorithms (around line 54), add:
// When ensemble is enabled for vacalibration, ensure at least 2 upload rows
if (jobType === 'vacalibration' && ensemble) {
  setUploads(prev => prev.length < 2
    ? [{ algorithm: '', file: null }, { algorithm: '', file: null }]
    : prev
  );
} else {
  // Non-ensemble: collapse to single upload row
  setUploads(prev => prev.length > 1 ? [prev[0]] : prev);
}
```

Replace the file upload section (lines 369-398) with conditional UI:

For **vacalibration + ensemble** — show dynamic upload rows:
```jsx
{jobType === 'vacalibration' && ensemble ? (
  <div className="form-group">
    <label>VA Data Files (one CSV per algorithm)</label>
    {uploads.map((upload, index) => (
      <div key={index} className="upload-row">
        <CustomSelect
          value={upload.algorithm}
          onChange={(val) => updateUpload(index, 'algorithm', val)}
          options={availableAlgorithms(index).map(a => ({
            value: a,
            label: a === 'InterVA' ? 'InterVA (fastest)' :
                   a === 'InSilicoVA' ? 'InSilicoVA (most accurate)' :
                   'EAVA (deterministic)'
          }))}
          placeholder="Select algorithm..."
        />
        <input
          type="file"
          accept=".csv"
          onChange={(e) => updateUpload(index, 'file', e.target.files[0])}
        />
        {upload.file && <span className="file-name">{upload.file.name}</span>}
        {uploads.length > 2 && (
          <button type="button" className="remove-upload" onClick={() => removeUpload(index)}>✕</button>
        )}
      </div>
    ))}
    {uploads.length < 3 && (
      <button type="button" className="add-upload" onClick={addUpload}>
        + Add Algorithm
      </button>
    )}
    <small className="form-hint">
      Upload separate CCVA output files for each algorithm.
    </small>
    <div className="sample-download">
      <div className="sample-links">
        <span>Sample CSV (neonate, 1190 records):</span>
        <a href={`${import.meta.env.BASE_URL}sample_interva_neonate.csv`} download>InterVA</a>
        <a href={`${import.meta.env.BASE_URL}sample_insilicova_neonate.csv`} download>InSilicoVA</a>
        <a href={`${import.meta.env.BASE_URL}sample_eava_neonate.csv`} download>EAVA</a>
      </div>
    </div>
  </div>
) : (
  /* Existing single file upload for non-ensemble / pipeline / openva */
  <div className="form-group">
    <label>VA Data File (CSV)</label>
    {/* For non-ensemble vacalibration, show algorithm dropdown next to file */}
    {jobType === 'vacalibration' && !ensemble && (
      <div className="upload-row">
        <CustomSelect
          value={uploads[0]?.algorithm || algorithms[0] || 'InterVA'}
          onChange={(val) => {
            updateUpload(0, 'algorithm', val);
            handleAlgorithmSelect(val);
          }}
          options={[
            { value: 'InterVA', label: 'InterVA (fastest)' },
            { value: 'InSilicoVA', label: 'InSilicoVA (most accurate)' },
            { value: 'EAVA', label: 'EAVA (deterministic)' }
          ]}
        />
      </div>
    )}
    <input
      type="file"
      accept=".csv"
      onChange={(e) => updateUpload(0, 'file', e.target.files[0])}
    />
    <small className="form-hint">
      {jobType === 'vacalibration'
        ? 'Required columns: ID, cause (with cause names)'
        : 'WHO 2016 VA questionnaire format (columns: i004a, i004b, ...)'}
    </small>
    {/* existing sample download links... keep as-is */}
  </div>
)}
```

Update `handleSubmit` to pass `uploads` instead of `file`:
```js
// In handleSubmit (line 109):
const result = await submitJob({
  uploads,  // replaces `file`
  jobType,
  algorithms,
  ageGroup,
  country,
  calibModelType,
  ensemble,
  nMCMC,
  nBurn,
  nThin
});
```

Update the submit button disabled condition (line 424):
```jsx
// Replace: disabled={loading || !file || activeJob}
// With:
disabled={loading || activeJob || (
  jobType === 'vacalibration' && ensemble
    ? uploads.some(u => !u.file || !u.algorithm)
    : !uploads[0]?.file
)}
```

Note: For pipeline ensemble, the existing checkbox UI (lines 218-250) stays, and the single file input is used. No upload rows for pipeline.

**Step 4: Run tests to verify they pass**

Run: `cd frontend && npm test -- --run`
Expected: All new and existing tests PASS

**Step 5: Commit**

```bash
git add frontend/src/components/JobForm.jsx frontend/src/components/JobForm.test.js
git commit -m "feat: add dynamic upload rows for ensemble calibration (#27, #17)

Replace single file input with per-algorithm upload rows when ensemble
is checked for vacalibration. Rows have algorithm dropdown, file picker,
and remove button. Max 3 rows, min 2 for ensemble."
```

---

### Task 2: Frontend — Update API client for multi-file uploads

**Files:**
- Modify: `frontend/src/api/client.js`
- Modify: `frontend/src/api/client.test.js`

**Step 1: Write failing tests for multi-file FormData**

Add to `frontend/src/api/client.test.js`:

```js
describe('submitJob multi-file support (issue #27)', () => {
  it('sends per-algorithm file keys for ensemble vacalibration', async () => {
    // Mock fetch
    const mockFetch = vi.fn().mockResolvedValue({
      json: () => Promise.resolve({ job_id: 'test-123', status: 'pending' })
    });
    globalThis.fetch = mockFetch;

    const { submitJob } = await import('./client.js');
    await submitJob({
      uploads: [
        { algorithm: 'InterVA', file: new File(['data'], 'interva.csv') },
        { algorithm: 'InSilicoVA', file: new File(['data'], 'insilicova.csv') }
      ],
      jobType: 'vacalibration',
      algorithms: ['InterVA', 'InSilicoVA'],
      ageGroup: 'neonate',
      country: 'Mozambique',
      calibModelType: 'Mmatprior',
      ensemble: true,
      nMCMC: 5000,
      nBurn: 2000,
      nThin: 1
    });

    const [url, options] = mockFetch.mock.calls[0];
    const formData = options.body;
    expect(formData.get('file_interva')).toBeTruthy();
    expect(formData.get('file_insilicova')).toBeTruthy();
    expect(formData.get('file')).toBeNull();  // no generic 'file' key
    expect(url).toContain('ensemble=true');
  });

  it('sends single file key for non-ensemble', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      json: () => Promise.resolve({ job_id: 'test-456', status: 'pending' })
    });
    globalThis.fetch = mockFetch;

    const { submitJob } = await import('./client.js');
    await submitJob({
      uploads: [
        { algorithm: 'InterVA', file: new File(['data'], 'test.csv') }
      ],
      jobType: 'vacalibration',
      algorithms: ['InterVA'],
      ageGroup: 'neonate',
      country: 'Mozambique',
      calibModelType: 'Mmatprior',
      ensemble: false,
      nMCMC: 5000,
      nBurn: 2000,
      nThin: 1
    });

    const [url, options] = mockFetch.mock.calls[0];
    const formData = options.body;
    expect(formData.get('file')).toBeTruthy();
    expect(formData.get('file_interva')).toBeNull();
  });
})
```

**Step 2: Run tests to verify they fail**

Run: `cd frontend && npm test -- --run`
Expected: FAIL — `submitJob` still expects `file` not `uploads`

**Step 3: Update submitJob in client.js**

Replace the `submitJob` function signature and FormData logic:

```js
export async function submitJob({ uploads, jobType, algorithms, ageGroup, country, calibModelType, ensemble, nMCMC, nBurn, nThin }) {
  const formData = new FormData();

  // Multi-file: ensemble vacalibration sends per-algorithm file keys
  const hasFiles = uploads && uploads.some(u => u.file);
  if (hasFiles && ensemble && jobType === 'vacalibration') {
    uploads.forEach(({ algorithm, file }) => {
      if (file && algorithm) {
        formData.append(`file_${algorithm.toLowerCase()}`, file);
      }
    });
  } else if (hasFiles) {
    // Single file for non-ensemble or pipeline
    const firstFile = uploads.find(u => u.file)?.file;
    if (firstFile) formData.append('file', firstFile);
  }

  const params = new URLSearchParams({
    job_type: jobType,
    algorithm: Array.isArray(algorithms) ? JSON.stringify(algorithms) : algorithms,
    age_group: ageGroup,
    country,
    calib_model_type: calibModelType,
    ensemble: String(ensemble),
    n_mcmc: String(nMCMC),
    n_burn: String(nBurn),
    n_thin: String(nThin)
  });

  return fetchJson(`${API_BASE}/jobs?${params}`, {
    method: 'POST',
    body: hasFiles ? formData : undefined
  });
}
```

**Step 4: Run tests to verify they pass**

Run: `cd frontend && npm test -- --run`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add frontend/src/api/client.js frontend/src/api/client.test.js
git commit -m "feat: send per-algorithm file keys in submitJob for ensemble (#27)"
```

---

### Task 3: Frontend — Update validation for ensemble uploads

**Files:**
- Modify: `frontend/src/components/JobForm.jsx`
- Modify: `frontend/src/components/JobForm.test.js`

**Step 1: Write failing tests for validation**

Add to `JobForm.test.js`:

```js
describe('Ensemble upload validation (issue #27)', () => {
  it('validates all upload rows have a file and algorithm for ensemble submission', () => {
    // The submit disabled logic should check uploads array
    expect(jobFormSrc).toContain('uploads.some')
  })

  it('syncs algorithms state from uploads when ensemble changes', () => {
    // When ensemble uploads change, the algorithms array should update
    expect(jobFormSrc).toContain('setAlgorithms')
  })
})
```

**Step 2: Run tests to verify they fail**

Run: `cd frontend && npm test -- --run`
Expected: FAIL if `uploads.some` not yet present (depends on Task 1 progress)

**Step 3: Add validation that syncs `algorithms` from `uploads` in ensemble mode**

In JobForm.jsx, add a useEffect to keep `algorithms` in sync with upload rows:

```js
// Sync algorithms from upload rows when in ensemble vacalibration mode
useEffect(() => {
  if (jobType === 'vacalibration' && ensemble) {
    const uploadAlgos = uploads.map(u => u.algorithm).filter(Boolean);
    if (uploadAlgos.length > 0) {
      setAlgorithms(uploadAlgos);
    }
  }
}, [uploads, jobType, ensemble]);
```

**Step 4: Run tests to verify they pass**

Run: `cd frontend && npm test -- --run`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add frontend/src/components/JobForm.jsx frontend/src/components/JobForm.test.js
git commit -m "feat: sync algorithms state from ensemble upload rows (#27)"
```

---

### Task 4: Backend — Accept multi-file uploads in POST /jobs

**Files:**
- Modify: `backend/plumber.R`

**Step 1: Write a failing test for multi-file backend acceptance**

Add to `tests/test_vacalibration_backend.R` (or a new section):

```r
# ------ Section: Multi-file upload file saving ------
message("=== Multi-file upload file saving ===")

# Test that save_multi_files helper correctly saves per-algorithm files
test_job_id <- "test-multi-upload"
test_upload_dir <- file.path(tempdir(), test_job_id)
dir.create(test_upload_dir, recursive = TRUE, showWarnings = FALSE)

# Simulate per-algorithm file data
test_csv <- "ID,cause\n1,Prematurity\n2,Sepsis"
writeLines(test_csv, file.path(test_upload_dir, "input_interva.csv"))
writeLines(test_csv, file.path(test_upload_dir, "input_insilicova.csv"))

stopifnot(file.exists(file.path(test_upload_dir, "input_interva.csv")))
stopifnot(file.exists(file.path(test_upload_dir, "input_insilicova.csv")))
message("  PASS: per-algorithm files saved correctly")

unlink(test_upload_dir, recursive = TRUE)
```

**Step 2: Run test to verify it passes (this is a setup test)**

Run: `cd backend && Rscript ../tests/test_vacalibration_backend.R --input-only`

**Step 3: Update plumber.R to handle multi-file uploads**

In the `POST /jobs` handler, after line 85 (`file_data <- req$args$file`), add multi-file extraction:

```r
# Handle multi-file uploads for ensemble vacalibration
file_interva <- req$args$file_interva
file_insilicova <- req$args$file_insilicova
file_eava <- req$args$file_eava
```

Replace the single-file save block (lines 153-234) with logic that handles both cases:

```r
# Save uploaded file(s)
upload_dir <- file.path("data", "uploads", job_id)
dir.create(upload_dir, recursive = TRUE, showWarnings = FALSE)

if (ensemble_bool && job_type == "vacalibration") {
  # Multi-file ensemble: save per-algorithm files
  algo_file_map <- list(
    interva = file_interva,
    insilicova = file_insilicova,
    eava = file_eava
  )

  files_saved <- character()
  for (algo in tolower(algorithms)) {
    fdata <- algo_file_map[[algo]]
    if (is.null(fdata)) {
      return(list(error = paste("Missing file for algorithm:", algo)))
    }
    input_path <- file.path(upload_dir, paste0("input_", algo, ".csv"))
    saved <- save_uploaded_file(fdata, input_path)
    if (!saved) {
      return(list(error = paste("Failed to save file for algorithm:", algo)))
    }
    files_saved <- c(files_saved, input_path)
  }
  job$input_files <- files_saved
} else if (!is.null(file_data)) {
  # Single file (non-ensemble or pipeline)
  input_path <- file.path(upload_dir, "input.csv")
  file_saved <- save_uploaded_file(file_data, input_path)
  if (!file_saved) {
    return(list(error = paste("Failed to save uploaded file. File data type:", class(file_data))))
  }
  job$input_file <- input_path
}
```

Extract the existing file-save logic into a reusable `save_uploaded_file(file_data, path)` helper function (place it before the endpoint handlers):

```r
# Helper: save a file from plumber's multipart upload
save_uploaded_file <- function(file_data, output_path) {
  tryCatch({
    if (is.raw(file_data)) {
      writeBin(file_data, output_path)
      TRUE
    } else if (is.character(file_data) && length(file_data) == 1 && file.exists(file_data)) {
      file.copy(file_data, output_path)
      TRUE
    } else if (is.character(file_data)) {
      writeLines(file_data, output_path)
      TRUE
    } else if (is.list(file_data)) {
      if (!is.null(file_data$datapath)) {
        file.copy(file_data$datapath, output_path)
        TRUE
      } else if (!is.null(file_data$value)) {
        if (is.raw(file_data$value)) {
          writeBin(file_data$value, output_path)
        } else {
          writeLines(as.character(file_data$value), output_path)
        }
        TRUE
      } else if (length(file_data) > 0) {
        for (elem in file_data) {
          if (is.raw(elem)) { writeBin(elem, output_path); return(TRUE) }
          if (is.character(elem) && length(elem) == 1 && file.exists(elem)) { file.copy(elem, output_path); return(TRUE) }
          if (is.character(elem)) { writeLines(elem, output_path); return(TRUE) }
          if (is.list(elem) && !is.null(elem$datapath)) { file.copy(elem$datapath, output_path); return(TRUE) }
        }
        FALSE
      } else { FALSE }
    } else { FALSE }
  }, error = function(e) {
    message("File save error: ", e$message)
    FALSE
  })
}
```

Update the file tracking section (lines 241-244) to handle multi-file:

```r
# Track uploaded files in database
if (!is.null(job$input_files)) {
  for (fpath in job$input_files) {
    fname <- basename(fpath)
    fsize <- file.info(fpath)$size
    add_job_file(job_id, "input", fname, fpath, fsize)
  }
} else if (!is.null(job$input_file)) {
  file_size <- file.info(job$input_file)$size
  add_job_file(job_id, "input", "input.csv", job$input_file, file_size)
}
```

Also update the pipeline validation (line 127-129) to allow ensemble:

```r
# Pipeline supports ensemble now (multiple algorithms, single file)
if (job_type == "pipeline" && ensemble_bool && length(algorithms) < 2) {
  return(list(error = "Pipeline ensemble requires at least 2 algorithms"))
}
```

**Step 4: Run tests to verify backend starts without errors**

Run: `cd backend && Rscript -e "source('plumber.R'); cat('OK\n')"`
Expected: No parse errors

**Step 5: Commit**

```bash
git add backend/plumber.R
git commit -m "feat: accept multi-file uploads for ensemble calibration (#27)

Extract save_uploaded_file helper. Handle per-algorithm file keys
(file_interva, file_insilicova, file_eava) for ensemble vacalibration.
Allow pipeline ensemble (multi-algo, single file)."
```

---

### Task 5: Backend — Update run_vacalibration() to load per-algorithm files

**Files:**
- Modify: `backend/jobs/algorithms/vacalibration.R`

**Step 1: Write failing test for multi-file loading**

Add a section to `tests/test_vacalibration_backend.R`:

```r
# ------ Section: Multi-file ensemble loading ------
message("=== Multi-file ensemble loading ===")

# Create test job with input_files (simulates ensemble upload)
test_job <- list(
  id = "test-ensemble-upload",
  algorithm = c("InterVA", "InSilicoVA"),
  age_group = "neonate",
  country = "Mozambique",
  ensemble = TRUE,
  use_sample_data = FALSE,
  input_files = c(
    "data/uploads/test-ensemble-upload/input_interva.csv",
    "data/uploads/test-ensemble-upload/input_insilicova.csv"
  )
)

# Verify input_files field is used when present
stopifnot(!is.null(test_job$input_files))
stopifnot(length(test_job$input_files) == 2)
message("  PASS: input_files field correctly structured")
```

**Step 2: Run test**

Run: `cd backend && Rscript ../tests/test_vacalibration_backend.R --input-only`

**Step 3: Update run_vacalibration() to handle per-algorithm files**

In `backend/jobs/algorithms/vacalibration.R`, replace the user upload block (lines 40-81) with:

```r
  } else if (!is.null(job$input_files)) {
    # Multi-file ensemble upload: one CSV per algorithm
    for (fpath in job$input_files) {
      # Extract algorithm from filename: input_interva.csv -> interva
      fname <- tools::file_path_sans_ext(basename(fpath))
      algo_from_file <- sub("^input_", "", fname)

      add_log(job$id, paste("Loading data from:", fpath, "(", algo_from_file, ")"))
      input_data <- read.csv(fpath, stringsAsFactors = FALSE)

      if ("cause1" %in% names(input_data) && !"cause" %in% names(input_data)) {
        names(input_data)[names(input_data) == "cause1"] <- "cause"
        add_log(job$id, "Auto-renamed 'cause1' to 'cause' (openVA format detected)")
      }

      if (!all(c("ID", "cause") %in% names(input_data))) {
        stop(paste("File", basename(fpath), "must have 'ID' and 'cause' columns"))
      }

      input_data$ID <- as.character(input_data$ID)
      add_log(job$id, paste("Loaded", nrow(input_data), "records with",
                            length(unique(input_data$cause)), "unique causes"))

      if (is_broad_format(input_data$cause, job$age_group)) {
        add_log(job$id, "Causes already in broad format, skipping cause_map()")
        va_broad <- build_broad_matrix(input_data, job$age_group)
      } else {
        add_log(job$id, "Mapping specific causes to broad categories...")
        input_data_fixed <- fix_causes_for_vacalibration(input_data)
        va_broad <- safe_cause_map(df = input_data_fixed, age_group = job$age_group)
      }

      va_input[[algo_from_file]] <- va_broad
    }

    # Build cause display from last loaded file (they share the same broad categories)
    cause_display_names <- build_cause_display_map(input_data, va_broad)
    cause_order <- build_cause_order(va_broad)

  } else {
    # Single file upload (existing logic)
```

The full conditional becomes: `if (isTRUE(job$use_sample_data)) { ... } else if (!is.null(job$input_files)) { ... } else { ... }`

**Step 4: Run tests**

Run: `cd backend && Rscript ../tests/test_vacalibration_backend.R --input-only`
Expected: PASS

**Step 5: Commit**

```bash
git add backend/jobs/algorithms/vacalibration.R
git commit -m "feat: load per-algorithm CSVs for ensemble user uploads (#27)

When job has input_files (multi-file upload), load each CSV and extract
algorithm name from filename. Build va_input dict for vacalibration."
```

---

### Task 6: Backend — Update run_pipeline() to support ensemble

**Files:**
- Modify: `backend/jobs/processor.R`

**Step 1: Write failing test concept**

The pipeline currently errors if `length(algorithms) > 1`. We need it to:
1. Run openVA per algorithm from the single input file
2. Feed all outputs into vacalibration with ensemble=TRUE

Test assertion: pipeline job with 2 algorithms and ensemble=TRUE should not error at validation.

**Step 2: Implement pipeline ensemble in processor.R**

Replace `run_pipeline()` (lines 62-272) with an updated version that handles ensemble.

Key changes to `run_pipeline()`:

After loading input data (line 74), loop over all algorithms instead of just the first:

```r
# Step 1: Run openVA — single algo or multi-algo for ensemble
ensemble_val <- isTRUE(job$ensemble) && length(algorithms) >= 2
algorithms <- if (is.character(job$algorithm)) job$algorithm else as.character(job$algorithm)

if (ensemble_val) {
  add_log(job$id, paste("Pipeline ensemble: running openVA for", paste(algorithms, collapse=", ")))
} else {
  algorithms <- algorithms[1]  # Single algo
}

va_input <- list()
all_cod <- NULL

for (algo in algorithms) {
  algo_name <- normalize_algo_name(algo)
  add_log(job$id, paste("Running openVA:", algo))

  # ... existing per-algorithm openVA code (InterVA/InSilicoVA/EAVA switch) ...

  cod <- getTopCOD(openva_result)

  va_data_df <- data.frame(ID = cod$ID, cause = cod$cause1, stringsAsFactors = FALSE)
  va_data_df_fixed <- fix_causes_for_vacalibration(va_data_df)
  va_broad <- safe_cause_map(df = va_data_df_fixed, age_group = job$age_group)

  va_input[[algo_name]] <- va_broad

  if (is.null(all_cod)) all_cod <- cod else all_cod <- rbind(all_cod, cod)

  add_log(job$id, paste("openVA", algo, "complete:", nrow(cod), "causes assigned"))
}

# Build cause display from last processed
cause_display_names <- build_cause_display_map(va_data_df, va_broad)
cause_order <- build_cause_order(va_broad)
```

Then run vacalibration with ensemble flag:

```r
# Step 3: Run vacalibration
calib_result <- run_with_capture(job$id, {
  vacalibration(
    va_data = va_input,
    age_group = job$age_group,
    country = job$country,
    calibmodel.type = calib_model_type,
    ensemble = ensemble_val,
    nMCMC = n_mcmc,
    nBurn = n_burn,
    nThin = n_thin,
    plot_it = FALSE,
    verbose = TRUE
  )
})
```

Extract results using the same ensemble-aware logic from `run_vacalibration()`:

```r
# Extract results — ensemble-aware
result_labels <- dimnames(calib_result$pcalib_postsumm)[[1]]
primary <- if ("ensemble" %in% result_labels) "ensemble" else result_labels[1]

uncalibrated   <- as.list(round(calib_result$p_uncalib[primary, ], 4))
calibrated     <- as.list(round(calib_result$pcalib_postsumm[primary, "postmean", ], 4))
calibrated_low <- as.list(round(calib_result$pcalib_postsumm[primary, "lowcredI", ], 4))
calibrated_high <- as.list(round(calib_result$pcalib_postsumm[primary, "upcredI", ], 4))
```

Also add `per_algorithm` breakdown if ensemble (same pattern as in `run_vacalibration()`).

**Step 3: Run backend smoke test**

Run: `cd backend && Rscript -e "source('plumber.R'); cat('OK\n')"`
Expected: No parse errors

**Step 4: Commit**

```bash
git add backend/jobs/processor.R
git commit -m "feat: support pipeline ensemble — run openVA per algorithm (#27)

Pipeline with ensemble=TRUE now runs openVA once per selected algorithm
from the single input file, then feeds all outputs into vacalibration
with ensemble=TRUE."
```

---

### Task 7: Frontend — Add CSS for upload rows

**Files:**
- Modify: `frontend/src/index.css` (or wherever styles live — check `frontend/src/` for CSS files)

**Step 1: Find the CSS file**

Run: `ls frontend/src/*.css`

**Step 2: Add styles for `.upload-row`, `.add-upload`, `.remove-upload`, `.file-name`**

```css
.upload-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.upload-row .custom-select {
  min-width: 180px;
}

.upload-row input[type="file"] {
  flex: 1;
}

.file-name {
  font-size: 0.85em;
  color: var(--text-secondary, #666);
  max-width: 150px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.remove-upload {
  background: none;
  border: 1px solid var(--border-color, #ddd);
  border-radius: 4px;
  cursor: pointer;
  padding: 0.25rem 0.5rem;
  color: var(--text-secondary, #999);
  font-size: 0.9em;
}

.remove-upload:hover {
  color: #e74c3c;
  border-color: #e74c3c;
}

.add-upload {
  background: none;
  border: 1px dashed var(--border-color, #ddd);
  border-radius: 4px;
  cursor: pointer;
  padding: 0.5rem 1rem;
  color: var(--text-secondary, #666);
  width: 100%;
  margin-top: 0.25rem;
}

.add-upload:hover {
  border-color: var(--accent, #4a90d9);
  color: var(--accent, #4a90d9);
}
```

**Step 3: Commit**

```bash
git add frontend/src/*.css
git commit -m "style: add CSS for ensemble upload rows (#27)"
```

---

### Task 8: Integration test — end-to-end ensemble upload

**Files:**
- Modify: `frontend/src/api/integration.test.js` (if exists) or add to existing test

**Step 1: Verify the ensemble flow works end-to-end**

This is a manual verification step. Start backend and frontend:

```bash
cd backend && Rscript run.R &
cd frontend && npm run dev
```

Test in browser:
1. Select "Calibration Only" job type
2. Check "Ensemble Mode"
3. Verify 2 upload rows appear with algorithm dropdowns
4. Add a third row with "+ Add Algorithm"
5. Verify dropdowns filter already-selected algorithms
6. Upload sample CSVs for InterVA and InSilicoVA
7. Click "Calibrate" and verify job completes

**Step 2: Run all frontend tests**

Run: `cd frontend && npm test -- --run`
Expected: All tests PASS

**Step 3: Run backend tests**

Run: `cd backend && Rscript ../tests/test_vacalibration_backend.R --input-only`
Expected: All tests PASS

**Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "test: verify multi-upload ensemble integration (#27)"
```
