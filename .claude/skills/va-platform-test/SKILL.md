---
name: va-platform-test
description: This skill performs comprehensive three-phase testing of the Verbal Autopsy Calibration Platform. Use this skill when validating the platform's backend API endpoints, frontend-backend integration, or running end-to-end browser tests. Trigger this skill when the user requests testing, validation, or quality assurance of the VA platform.
---

# VA Platform Test

## Overview

Design-first validation framework for the Verbal Autopsy Calibration Platform. This skill evaluates whether the platform's architecture makes sense before testing implementation details. Each phase emphasizes understanding the design philosophy first, then optionally using automated tools to verify correctness.

## When to Use This Skill

Use this skill when:
- User requests to test the platform
- Validating changes to backend or frontend code
- Evaluating overall system architecture
- Troubleshooting integration or design issues
- Performing quality assurance before deployment
- User explicitly asks to "test the VA platform" or "run tests"

## Testing Philosophy

**Understanding First, Scripts Second**: Each phase starts by reading and understanding the design. Scripts are reference tools to catch mechanical errors, not the primary validation method. Focus on:
1. Does the design make sense for the use case?
2. Are the architectural choices appropriate?
3. Does the implementation match the intended design?

## Related Skills

This skill leverages domain expertise from other skills:

- **openVA skill** - Provides deep knowledge of openVA R package (algorithms, data formats, expected behaviors)
- **vacalibration skill** - Provides expertise on vacalibration R package (calibration methods, Bayesian models, CSMF outputs)

**When to use these skills during testing:**

1. **Phase 1 (Backend)**: When evaluating how the backend uses openVA/vacalibration packages
   - Consult openVA skill to understand expected algorithm behaviors, data formats, parameter requirements
   - Consult vacalibration skill to validate calibration logic, understand ensemble mode, verify output structures
   - Use these skills to assess if the backend is using the packages correctly

2. **Phase 2 (Integration)**: When frontend needs to expose package-specific features
   - Check if frontend parameters match what openVA/vacalibration actually support
   - Verify that UI options align with actual package capabilities

3. **Phase 3 (UX)**: When evaluating user-facing terminology and workflow
   - Ensure UI uses correct domain terminology (CSMF, calibration, algorithms)
   - Verify that workflow matches how researchers actually use these packages

**How to invoke:**
When you need domain expertise about the underlying R packages, pause testing and consult the relevant skill. For example: "Let me check the openVA skill to understand how InterVA parameters work..." then resume testing with that knowledge.

## Testing Workflow

Execute all three phases in order. Each phase has two steps: **Understand** → **Validate**.

### Phase 1: Backend Design & Architecture

**Step 1: Understand the Backend Design**

Read and analyze the backend architecture before testing anything.

**Files to review:**
- `backend/plumber.R` - API endpoint definitions
- `backend/jobs/processor.R` - Job processing logic
- `backend/run.R` - Server startup (if exists)

**Questions to answer:**

1. **API Design Quality**
   - Are endpoints RESTful and logically organized?
   - Do endpoints follow consistent naming conventions?
   - Is the job lifecycle (submit → status → log → results) well-designed?

2. **Async Job Processing**
   - How are long-running jobs handled? (File-based storage, futures, background workers?)
   - Is the job state management appropriate for the use case?
   - Can the system handle multiple concurrent jobs?

3. **Error Handling**
   - How does the API handle invalid inputs?
   - Are error messages informative for debugging?
   - Does the API distinguish between client errors (400s) and server errors (500s)?

4. **Data Flow**
   - How does data flow from upload → processing → results?
   - Is file storage organized logically?
   - Are there any potential race conditions or file conflicts?

5. **Algorithm Support**
   - How are different algorithms (InterVA, InSilicoVA, EAVA) supported?
   - Is ensemble mode properly implemented?
   - Are there any hardcoded assumptions that limit flexibility?

**💡 Domain Expertise Checkpoint:**
When evaluating algorithm support and calibration logic, consult the related skills:
- **openVA skill** - Understand how `codeVA()`, algorithm parameters, and data formats should work
- **vacalibration skill** - Understand `vacalibration()` function, ensemble mode requirements, calibration models
- Compare backend implementation against package best practices

**Design Assessment:**
After reading the code, assess whether the backend architecture makes sense for:
- Long-running statistical computations (openVA can take minutes)
- Multiple job types (openva only, vacalibration only, full pipeline)
- File-based inputs and outputs
- RESTful client communication

**Step 2: Validate Backend Works**

Once you understand the design, optionally verify it actually works:

```bash
python .claude/skills/va-platform-test/scripts/test_backend.py
```

The script tests mechanical correctness (endpoints return 200, jobs progress through states), but **understanding the design is more important than passing automated tests**. A poorly designed system that passes tests is still poorly designed.

**If issues found:**
- Design problems → Discuss with user, may need architectural changes
- Implementation bugs → Fix the code, retest
- Configuration issues → Check R packages, file permissions, server settings

### Phase 2: Frontend-Backend Design Alignment

**Step 1: Understand the Frontend Design**

Read and analyze how the frontend is architected and whether it matches backend capabilities.

**Files to review:**
- `frontend/src/api/client.js` - API client implementation
- `frontend/src/pages/*.jsx` - Page components (Jobs, Results)
- `frontend/src/components/*.jsx` - Reusable components
- `frontend/src/App.jsx` - Application structure and routing

**Questions to answer:**

1. **API Client Design**
   - How does the frontend abstract backend calls?
   - Is there a clean separation between API layer and UI layer?
   - How are async operations (job polling) handled?

2. **State Management**
   - How is application state managed? (React state, context, external library?)
   - Is this appropriate for tracking job status and results?
   - How does the app handle real-time updates (polling, websockets, manual refresh)?

3. **User Workflow Alignment**
   - Does the frontend UI flow match what the backend supports?
   - Are there UI features that the backend doesn't support (or vice versa)?
   - Is the job submission form aligned with backend parameters?

**💡 Domain Expertise Checkpoint:**
When evaluating parameter alignment and feature coverage:
- **openVA skill** - Verify frontend exposes all supported algorithms, age groups, and data types correctly
- **vacalibration skill** - Check if ensemble mode, calibration models, and country options match package capabilities
- Ensure frontend doesn't promise features the packages can't deliver

4. **Error Handling & UX**
   - How does the frontend handle backend errors?
   - Are loading states and pending jobs clearly indicated?
   - Does the UI provide helpful feedback when things go wrong?

5. **Data Presentation**
   - How are calibration results displayed to users?
   - Is the data visualization appropriate for the domain (VA research)?
   - Can users easily understand and export their results?

**Design Coherence Assessment:**
After reviewing both frontend and backend, evaluate:
- Does the frontend design philosophy match backend capabilities?
- Are there gaps where the backend offers features the UI doesn't expose?
- Are there UI patterns that fight against the backend's async job model?
- Is the overall architecture consistent (REST + polling vs websockets vs other)?

**Step 2: Check Integration Mechanics**

Once you understand the design alignment, optionally verify parameter mappings:

```bash
python .claude/skills/va-platform-test/scripts/check_integration.py --project-root .
```

The script catches mechanical mismatches (wrong endpoint URLs, missing parameters), but **understanding whether the frontend and backend designs are philosophically aligned matters more**. Perfect parameter mapping doesn't fix a fundamentally mismatched architecture.

**If issues found:**
- Design misalignment → Discuss tradeoffs, may need to rethink UI or backend
- Parameter mismatches → Fix the mapping, usually straightforward
- Missing features → Decide whether to add to frontend, backend, or both

### Phase 3: End-to-End User Experience

**Step 1: Understand the User Journey**

Before testing mechanically, understand what the user experience *should* be.

**Questions to answer:**

1. **User Mental Model**
   - Who is the target user? (Researchers, epidemiologists, data analysts?)
   - What is their goal? (Process VA data, calibrate cause-of-death estimates)
   - What level of technical expertise do they have?

2. **Workflow Design**
   - What is the intended user journey from start to finish?
   - How does the UI guide users through the workflow?
   - Are there clear next steps at each stage?

3. **Information Architecture**
   - Is information organized in a way that makes sense to domain experts?
   - Can users find what they need without hunting?
   - Are technical details (algorithm names, parameters) explained adequately?

4. **Feedback & Communication**
   - How does the system communicate job progress to users?
   - What happens during the 30-60 second wait for job completion?
   - Are error messages actionable or just confusing?

5. **Results Interpretation**
   - Can users understand the calibration results?
   - Is the difference between uncalibrated and calibrated CSMF clear?
   - Can users export and use the results in their research?

**💡 Domain Expertise Checkpoint:**
Before experiencing the user journey, consult domain skills to understand proper terminology and workflow:
- **openVA skill** - Learn correct terminology (CSMF, VA data, algorithm names) and typical researcher workflows
- **vacalibration skill** - Understand calibration concepts, what results mean, how researchers interpret calibrated CSMFs
- Use this knowledge to evaluate if the UI speaks the language of VA researchers

**Step 2: Experience the User Journey**

Navigate through the application as a user would, using browser automation:

**Setup:**
1. Ensure both services are running (backend on :8000, frontend on :3000)
2. Get browser context: `tabs_context_mcp`
3. Create or navigate to a tab

**User Journey to Experience:**

1. **Landing / Job Submission**
   - Navigate to `http://localhost:3000`
   - Observe: Is the purpose of the application immediately clear?
   - Look at the form: Are the options well-labeled and understandable?
   - Try submitting a demo job or real job
   - Assess: Is it obvious what each parameter does?

2. **Job Tracking**
   - After submission, what happens next?
   - How does the user know their job is processing?
   - Navigate to jobs list (if separate page)
   - Observe: Can users easily track multiple jobs?
   - Wait and watch: How does status update? Is it clear and reassuring?

3. **Results Review**
   - Once job completes, navigate to results
   - Observe: Is the data presentation clear and useful?
   - Look at calibrated vs uncalibrated results
   - Assess: Would a researcher understand these outputs?
   - Check: Can results be downloaded easily?

4. **Error Scenarios**
   - Try invalid inputs (if backend allows form submission)
   - Observe: Are error messages helpful or cryptic?
   - Try accessing a job that doesn't exist
   - Assess: Does the UI handle edge cases gracefully?

**Critical Assessment:**

After experiencing the user journey, evaluate:
- **Does this make sense?** Would the target user be able to accomplish their goals?
- **Is it intuitive?** Or does it require prior knowledge of the system?
- **What's confusing?** Where would users get stuck or frustrated?
- **What's missing?** Are there gaps in the workflow?
- **What could be better?** Even if it works, how could UX improve?

**Step 3: Verify Functionality**

After understanding the UX, verify the mechanics work:
- Forms submit correctly
- Status updates happen automatically
- Results display properly
- Downloads work
- Navigation flows correctly

But remember: **A working system with poor UX is not a successful system**. Focus on whether the experience makes sense, not just whether buttons click.

## Using the API Reference

For detailed endpoint documentation, parameter specifications, and expected response formats, consult `references/api_reference.md`.

Load the reference when:
- Understanding the intended API contract
- Debugging specific endpoint behaviors
- Implementing new frontend API calls
- Validating response structures

The reference documents the "what", but you still need to evaluate the "why" - whether the API design makes sense for the use case.

## Key Principles

1. **Understand Before Testing**
   - Read the code to understand design intent
   - Assess whether the architecture is appropriate
   - Scripts are helpers, not the primary evaluation method

2. **Design Quality Over Implementation Correctness**
   - A well-designed system with bugs is easier to fix than a poorly designed system that works
   - Focus on architectural soundness first
   - Implementation details second

3. **User Experience Matters Most**
   - Technical correctness doesn't guarantee user success
   - Always evaluate from the target user's perspective
   - The system should make sense to non-technical researchers

4. **Context-Aware Testing**
   - Consider the domain (VA research, statistical analysis)
   - Understand the constraints (R environment, long-running jobs, file-based data)
   - Evaluate appropriateness, not just correctness

## When to Use Scripts vs Manual Assessment

**Use automated scripts when:**
- Verifying mechanical correctness after design review
- Catching regression errors quickly
- Validating large numbers of endpoints

**Use manual assessment when:**
- Evaluating architectural decisions
- Understanding user experience
- Judging design coherence
- Identifying improvement opportunities

## Common Issues and Root Causes

**Backend doesn't respond**
- Surface: Scripts fail, endpoints return errors
- Root cause: Server not running, R package issues, port conflicts
- Fix: Check R console, verify dependencies, restart server

**Frontend and backend mismatched**
- Surface: Integration script shows mismatches
- Root cause: Often a design evolution mismatch, not a bug
- Fix: Understand why they diverged, align intentionally

**System works but feels wrong**
- Surface: All tests pass, but UX is confusing
- Root cause: Design doesn't match user mental model
- Fix: Rethink information architecture, not code

**Jobs never complete**
- Surface: Status stays "pending" forever
- Root cause: Background processing not working, R errors in job execution
- Fix: Check backend logs, verify file permissions, test R packages directly

## Resources

### scripts/
Optional automated validation tools. Use after understanding the design:
- `test_backend.py` - Validates backend API mechanical correctness
- `check_integration.py` - Checks frontend-backend parameter alignment

These scripts catch implementation errors but don't evaluate design quality.

### references/
Documentation to support design understanding:
- `api_reference.md` - Complete API specification with expected behaviors, parameters, and response formats

Consult when you need detailed specifications, but remember to assess whether the design itself makes sense for the use case.
