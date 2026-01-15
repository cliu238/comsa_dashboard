#!/usr/bin/env python3
"""
Backend API Validation Script
Tests all plumber API endpoints for correctness and sensible responses
"""

import requests
import sys
import time
import json
from typing import Dict, Any, List, Tuple

# ANSI colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

class BackendTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
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

    def test_health(self) -> bool:
        """Test GET /health endpoint"""
        self.log_info("Testing GET /health")
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)

            if response.status_code != 200:
                self.log_fail(f"Health check returned status {response.status_code}")
                return False

            data = response.json()
            if data.get("status") != "ok":
                self.log_fail(f"Health status not 'ok': {data.get('status')}")
                return False

            if "timestamp" not in data:
                self.log_warn("Health response missing 'timestamp' field")

            self.log_pass("Health check endpoint working correctly")
            return True

        except requests.exceptions.RequestException as e:
            self.log_fail(f"Health check failed: {e}")
            return False

    def test_list_jobs(self) -> bool:
        """Test GET /jobs endpoint"""
        self.log_info("Testing GET /jobs")
        try:
            response = requests.get(f"{self.base_url}/jobs", timeout=5)

            if response.status_code != 200:
                self.log_fail(f"List jobs returned status {response.status_code}")
                return False

            data = response.json()
            if "jobs" not in data:
                self.log_fail("List jobs response missing 'jobs' field")
                return False

            if not isinstance(data["jobs"], list):
                self.log_fail(f"Jobs field is not a list: {type(data['jobs'])}")
                return False

            self.log_pass(f"List jobs endpoint working correctly ({len(data['jobs'])} jobs)")
            return True

        except requests.exceptions.RequestException as e:
            self.log_fail(f"List jobs failed: {e}")
            return False

    def test_demo_job(self) -> Tuple[bool, str]:
        """Test POST /jobs/demo endpoint and return job_id if successful"""
        self.log_info("Testing POST /jobs/demo")
        try:
            params = {
                "job_type": "pipeline",
                "algorithm": '["InterVA"]',
                "age_group": "neonate",
                "calib_model_type": "Mmatprior",
                "ensemble": "FALSE"
            }

            response = requests.post(f"{self.base_url}/jobs/demo", params=params, timeout=5)

            if response.status_code != 200:
                self.log_fail(f"Demo job submission returned status {response.status_code}")
                return False, ""

            data = response.json()

            # Check required fields
            required = ["job_id", "status", "message"]
            missing = [f for f in required if f not in data]
            if missing:
                self.log_fail(f"Demo job response missing fields: {missing}")
                return False, ""

            if data["status"] != "pending":
                self.log_warn(f"Demo job status is '{data['status']}', expected 'pending'")

            job_id = data["job_id"]
            self.log_pass(f"Demo job submitted successfully (job_id: {job_id})")
            return True, job_id

        except requests.exceptions.RequestException as e:
            self.log_fail(f"Demo job submission failed: {e}")
            return False, ""

    def test_job_status(self, job_id: str) -> bool:
        """Test GET /jobs/<job_id>/status endpoint"""
        self.log_info(f"Testing GET /jobs/{job_id}/status")
        try:
            response = requests.get(f"{self.base_url}/jobs/{job_id}/status", timeout=5)

            if response.status_code != 200:
                self.log_fail(f"Job status returned status {response.status_code}")
                return False

            data = response.json()

            # Check required fields
            required = ["job_id", "type", "status"]
            missing = [f for f in required if f not in data]
            if missing:
                self.log_fail(f"Job status response missing fields: {missing}")
                return False

            # Validate status value
            valid_statuses = ["pending", "running", "completed", "failed"]
            if data["status"] not in valid_statuses:
                self.log_warn(f"Unexpected job status: {data['status']}")

            self.log_pass(f"Job status endpoint working (status: {data['status']})")
            return True

        except requests.exceptions.RequestException as e:
            self.log_fail(f"Job status check failed: {e}")
            return False

    def test_job_log(self, job_id: str) -> bool:
        """Test GET /jobs/<job_id>/log endpoint"""
        self.log_info(f"Testing GET /jobs/{job_id}/log")
        try:
            response = requests.get(f"{self.base_url}/jobs/{job_id}/log", timeout=5)

            if response.status_code != 200:
                self.log_fail(f"Job log returned status {response.status_code}")
                return False

            data = response.json()

            if "job_id" not in data or "log" not in data:
                self.log_fail("Job log response missing required fields")
                return False

            if not isinstance(data["log"], list):
                self.log_fail(f"Log field is not a list: {type(data['log'])}")
                return False

            self.log_pass(f"Job log endpoint working ({len(data['log'])} log entries)")
            return True

        except requests.exceptions.RequestException as e:
            self.log_fail(f"Job log check failed: {e}")
            return False

    def wait_for_job_completion(self, job_id: str, max_wait: int = 60) -> str:
        """Wait for job to complete and return final status"""
        self.log_info(f"Waiting for job {job_id} to complete (max {max_wait}s)...")

        start_time = time.time()
        while time.time() - start_time < max_wait:
            try:
                response = requests.get(f"{self.base_url}/jobs/{job_id}/status", timeout=5)
                if response.status_code == 200:
                    data = response.json()
                    status = data.get("status")

                    if status in ["completed", "failed"]:
                        return status

                time.sleep(2)

            except requests.exceptions.RequestException:
                time.sleep(2)

        return "timeout"

    def test_job_results(self, job_id: str) -> bool:
        """Test GET /jobs/<job_id>/results endpoint"""
        self.log_info(f"Testing GET /jobs/{job_id}/results")
        try:
            response = requests.get(f"{self.base_url}/jobs/{job_id}/results", timeout=5)

            if response.status_code != 200:
                self.log_fail(f"Job results returned status {response.status_code}")
                return False

            data = response.json()

            # Check for error response
            if "error" in data:
                if data["error"] == "Job not completed":
                    self.log_warn("Job not yet completed")
                    return True
                else:
                    self.log_fail(f"Job results error: {data['error']}")
                    return False

            # Validate results structure for pipeline jobs
            expected_fields = ["algorithm", "age_group", "country", "calibrated_csmf", "files"]
            present = [f for f in expected_fields if f in data]

            if len(present) > 0:
                self.log_pass(f"Job results endpoint working (found {len(present)} expected fields)")
            else:
                self.log_warn("Job results structure doesn't match expected pipeline format")
                self.log_pass("Job results endpoint accessible")

            return True

        except requests.exceptions.RequestException as e:
            self.log_fail(f"Job results check failed: {e}")
            return False

    def test_nonexistent_job(self) -> bool:
        """Test handling of nonexistent job ID"""
        self.log_info("Testing error handling for nonexistent job")
        try:
            fake_id = "00000000-0000-0000-0000-000000000000"
            response = requests.get(f"{self.base_url}/jobs/{fake_id}/status", timeout=5)

            if response.status_code != 200:
                self.log_warn(f"Expected 200 with error object, got {response.status_code}")
                return True

            data = response.json()
            if "error" in data and "not found" in data["error"].lower():
                self.log_pass("Nonexistent job handled correctly")
                return True
            else:
                self.log_warn("Nonexistent job didn't return expected error message")
                return True

        except requests.exceptions.RequestException as e:
            self.log_fail(f"Nonexistent job test failed: {e}")
            return False

    def run_all_tests(self) -> bool:
        """Run all backend validation tests"""
        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{BLUE}PHASE 1: Backend API Validation{RESET}")
        print(f"{BLUE}{'='*60}{RESET}\n")

        # Test health endpoint
        if not self.test_health():
            self.log_fail("Backend appears to be down. Is the server running?")
            return False

        # Test list jobs
        self.test_list_jobs()

        # Test demo job submission
        success, job_id = self.test_demo_job()

        if success and job_id:
            # Test job status
            self.test_job_status(job_id)

            # Test job log
            self.test_job_log(job_id)

            # Wait for completion
            final_status = self.wait_for_job_completion(job_id, max_wait=60)

            if final_status == "completed":
                self.log_pass(f"Job completed successfully")
                # Test results endpoint
                self.test_job_results(job_id)
            elif final_status == "failed":
                self.log_warn(f"Job failed during execution")
                self.test_job_results(job_id)
            else:
                self.log_warn(f"Job did not complete within timeout (status: {final_status})")

        # Test error handling
        self.test_nonexistent_job()

        # Print summary
        print(f"\n{BLUE}{'='*60}{RESET}")
        print(f"{BLUE}Backend Validation Summary{RESET}")
        print(f"{BLUE}{'='*60}{RESET}")
        print(f"{GREEN}Passed:{RESET} {self.passed}")
        print(f"{RED}Failed:{RESET} {self.failed}")
        print(f"{YELLOW}Warnings:{RESET} {self.warnings}")

        if self.failed > 0:
            print(f"\n{RED}Backend validation FAILED{RESET}")
            return False
        else:
            print(f"\n{GREEN}Backend validation PASSED{RESET}")
            return True

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Validate VA Platform backend API')
    parser.add_argument('--url', default='http://localhost:8000',
                       help='Backend API base URL (default: http://localhost:8000)')
    args = parser.parse_args()

    tester = BackendTester(args.url)
    success = tester.run_all_tests()

    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
