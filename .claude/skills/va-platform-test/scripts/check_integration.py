#!/usr/bin/env python3
"""
Frontend-Backend Integration Checker
Verifies that frontend API calls match backend endpoint definitions
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple

# ANSI colors
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

class IntegrationChecker:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.backend_file = self.project_root / "backend" / "plumber.R"
        self.frontend_file = self.project_root / "frontend" / "src" / "api" / "client.js"

        self.passed = 0
        self.failed = 0
        self.warnings = 0

    def log_pass(self, message: str):
        print(f"{GREEN}✓{RESET} {message}")
        self.passed += 1

    def log_fail(self, message: str):
        print(f"{RED}✗{RESET} {message}")
        self.failed += 1

    def log_warn(self, message: str):
        print(f"{YELLOW}⚠{RESET} {message}")
        self.warnings += 1

    def log_info(self, message: str):
        print(f"{BLUE}ℹ{RESET} {message}")

    def parse_backend_endpoints(self) -> Dict[str, Dict]:
        """Parse plumber.R to extract API endpoints"""
        self.log_info("Parsing backend endpoints from plumber.R")

        if not self.backend_file.exists():
            self.log_fail(f"Backend file not found: {self.backend_file}")
            return {}

        content = self.backend_file.read_text()
        endpoints = {}

        # Match plumber endpoint annotations
        # Pattern: #* @get /path or #* @post /path
        pattern = r"#\*\s*@(get|post|put|delete)\s+(/[^\n]+)"

        matches = re.finditer(pattern, content, re.IGNORECASE)

        for match in matches:
            method = match.group(1).upper()
            path = match.group(2).strip()

            # Clean up path parameters
            path_clean = re.sub(r'<[^>]+>', '{param}', path)

            endpoint_key = f"{method} {path_clean}"
            endpoints[endpoint_key] = {
                "method": method,
                "path": path,
                "path_template": path_clean
            }

        self.log_pass(f"Found {len(endpoints)} backend endpoints")
        return endpoints

    def parse_frontend_calls(self) -> Dict[str, Dict]:
        """Parse client.js to extract API calls"""
        self.log_info("Parsing frontend API calls from client.js")

        if not self.frontend_file.exists():
            self.log_fail(f"Frontend file not found: {self.frontend_file}")
            return {}

        content = self.frontend_file.read_text()
        api_calls = {}

        # Extract base URL
        base_url_match = re.search(r"const\s+API_BASE\s*=\s*['\"]([^'\"]+)['\"]", content)
        base_url = base_url_match.group(1) if base_url_match else "http://localhost:8000"

        # Find all fetch calls
        # Pattern: fetch(`${API_BASE}/path`, { method: 'POST' })
        # or: fetchJson(`${API_BASE}/path`, ...)

        # Method 1: Direct fetch/fetchJson calls
        patterns = [
            r"(fetch|fetchJson)\(`\$\{API_BASE\}(/[^`]+)`[^)]*\{[^}]*method:\s*['\"](\w+)['\"]",
            r"(fetch|fetchJson)\(`\$\{API_BASE\}(/[^`]+)`[^)]*method:\s*['\"](\w+)['\"]",
        ]

        for pattern in patterns:
            for match in re.finditer(pattern, content):
                path = match.group(2)
                method = match.group(3).upper() if len(match.groups()) >= 3 else "GET"

                # Template variables in path
                path_clean = re.sub(r'\$\{[^}]+\}', '{param}', path)

                endpoint_key = f"{method} {path_clean}"
                api_calls[endpoint_key] = {
                    "method": method,
                    "path": path,
                    "path_template": path_clean
                }

        # Method 2: GET requests (no method specified means GET)
        get_pattern = r"(fetch|fetchJson)\(`\$\{API_BASE\}(/[^`]+)`"
        for match in re.finditer(get_pattern, content):
            path = match.group(2)
            path_clean = re.sub(r'\$\{[^}]+\}', '{param}', path)

            # Only add if not already added as POST/PUT/DELETE
            post_key = f"POST {path_clean}"
            get_key = f"GET {path_clean}"

            if post_key not in api_calls and get_key not in api_calls:
                api_calls[get_key] = {
                    "method": "GET",
                    "path": path,
                    "path_template": path_clean
                }

        self.log_pass(f"Found {len(api_calls)} frontend API calls")
        return api_calls

    def check_endpoint_coverage(self, backend: Dict, frontend: Dict):
        """Check if frontend covers all backend endpoints"""
        self.log_info("\nChecking endpoint coverage...")

        backend_keys = set(backend.keys())
        frontend_keys = set(frontend.keys())

        # Endpoints in backend but not in frontend
        missing_in_frontend = backend_keys - frontend_keys
        if missing_in_frontend:
            self.log_warn(f"Backend endpoints not used in frontend:")
            for key in sorted(missing_in_frontend):
                print(f"  {YELLOW}•{RESET} {key}")
                # Note: This is a warning, not a failure - some endpoints may be optional
        else:
            self.log_pass("All backend endpoints have corresponding frontend calls")

        # Endpoints in frontend but not in backend
        missing_in_backend = frontend_keys - backend_keys
        if missing_in_backend:
            self.log_fail(f"Frontend calls endpoints that don't exist in backend:")
            for key in sorted(missing_in_backend):
                print(f"  {RED}•{RESET} {key}")
        else:
            self.log_pass("All frontend API calls match backend endpoints")

        # Matching endpoints
        matching = backend_keys & frontend_keys
        if matching:
            self.log_pass(f"{len(matching)} endpoints correctly matched between frontend and backend")

    def check_parameter_consistency(self):
        """Check if frontend sends parameters expected by backend"""
        self.log_info("\nChecking parameter consistency...")

        # Read both files
        backend_content = self.backend_file.read_text()
        frontend_content = self.frontend_file.read_text()

        # Check submitJob parameters
        self.log_info("Checking submitJob() parameters...")

        # Expected parameters from backend POST /jobs
        backend_params = {
            "job_type", "algorithm", "age_group", "country",
            "calib_model_type", "ensemble", "file"
        }

        # Extract params from frontend submitJob
        submit_match = re.search(
            r"export async function submitJob\([^)]*\{([^}]+)\}",
            frontend_content
        )

        if submit_match:
            frontend_params_str = submit_match.group(1)
            frontend_params = {
                p.strip() for p in frontend_params_str.split(',')
            }

            # Map frontend camelCase to backend snake_case
            param_mapping = {
                "file": "file",
                "jobType": "job_type",
                "algorithms": "algorithm",
                "ageGroup": "age_group",
                "country": "country",
                "calibModelType": "calib_model_type",
                "ensemble": "ensemble"
            }

            backend_params_from_frontend = {
                param_mapping.get(p, p) for p in frontend_params
            }

            # Check coverage
            missing = backend_params - backend_params_from_frontend
            if missing and missing != {"file"}:  # file is optional
                self.log_warn(f"submitJob may be missing parameters: {missing}")
            else:
                self.log_pass("submitJob parameters match backend expectations")

        # Check API_BASE matches expected backend URL
        self.log_info("Checking API base URL...")
        base_url_match = re.search(r"const\s+API_BASE\s*=\s*['\"]([^'\"]+)['\"]", frontend_content)
        if base_url_match:
            base_url = base_url_match.group(1)
            if "localhost:8000" in base_url or "8000" in base_url:
                self.log_pass(f"API_BASE configured correctly: {base_url}")
            else:
                self.log_warn(f"API_BASE may need adjustment: {base_url}")

    def run_all_checks(self) -> bool:
        """Run all integration checks"""
        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{BLUE}PHASE 2: Frontend-Backend Integration Check{RESET}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        # Parse endpoints
        backend_endpoints = self.parse_backend_endpoints()
        frontend_calls = self.parse_frontend_calls()

        if not backend_endpoints or not frontend_calls:
            self.log_fail("Could not parse endpoints from source files")
            return False

        # Display what we found
        print(f"\n{BLUE}Backend Endpoints:{RESET}")
        for key in sorted(backend_endpoints.keys()):
            print(f"  {GREEN}•{RESET} {key}")

        print(f"\n{BLUE}Frontend API Calls:{RESET}")
        for key in sorted(frontend_calls.keys()):
            print(f"  {GREEN}•{RESET} {key}")

        # Run checks
        self.check_endpoint_coverage(backend_endpoints, frontend_calls)
        self.check_parameter_consistency()

        # Print summary
        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{BLUE}Integration Check Summary{RESET}")
        print(f"{BLUE}{'='*60}{RESET}")
        print(f"{GREEN}Passed:{RESET} {self.passed}")
        print(f"{RED}Failed:{RESET} {self.failed}")
        print(f"{YELLOW}Warnings:{RESET} {self.warnings}")

        if self.failed > 0:
            print(f"\n{RED}Integration check FAILED{RESET}")
            return False
        else:
            print(f"\n{GREEN}Integration check PASSED{RESET}")
            if self.warnings > 0:
                print(f"{YELLOW}(with {self.warnings} warnings){RESET}")
            return True

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Check frontend-backend integration')
    parser.add_argument('--project-root', default='.',
                       help='Project root directory (default: current directory)')
    args = parser.parse_args()

    checker = IntegrationChecker(args.project_root)
    success = checker.run_all_checks()

    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
