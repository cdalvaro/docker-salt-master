"""Run with python3 tests/test_ecr_login.py (stdlib only)."""

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
GUARD = (
    "github.actor != 'dependabot[bot]' && "
    "(github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository)"
)


class ECRLoginTests(unittest.TestCase):
    def test_login_is_guarded_and_precedes_image_operations(self):
        workflows = {
            "build-and-test.yml": {"build": "Start Docker registry", "test": "Execute Basic Tests"},
            "security-analysis.yml": {"security-analysis": "Build docker-salt-master Base Image"},
        }
        for filename, targets in workflows.items():
            source = (ROOT / ".github/workflows" / filename).read_text()
            self.assertNotIn("pull_request_target:", source)
            jobs = dict(re.findall(r"^  ([\w-]+):\n(.*?)(?=^  [\w-]+:\n|\Z)", source, re.M | re.S))
            for job_name, first_pull in targets.items():
                with self.subTest(workflow=filename, job=job_name):
                    job = jobs[job_name]
                    self.assertIn("      id-token: write\n", job)
                    self.assertIn("      contents: read\n", job)
                    steps = job.split("      - name: ")[1:]
                    configure = next(s for s in steps if "uses: aws-actions/configure-aws-credentials@" in s)
                    login = next(s for s in steps if "uses: aws-actions/amazon-ecr-login@" in s)
                    self.assertIn(f"        if: {GUARD}\n", configure)
                    self.assertIn(f"        if: {GUARD}\n", login)
                    self.assertIn("role-to-assume: ${{ vars.AWS_ECR_READ_ONLY_ROLE_ARN }}\n", configure)
                    self.assertIn("aws-region: us-east-1\n", configure)
                    self.assertIn("registry-type: public\n", login)
                    self.assertNotIn("mask-password: false", login)
                    self.assertNotIn("aws-access-key-id:", job)
                    self.assertNotIn("aws-secret-access-key:", job)
                    self.assertLess(job.index(configure), job.index(login))
                    self.assertLess(job.index(login), job.index(f"      - name: {first_pull}\n"))


if __name__ == "__main__":
    unittest.main()
