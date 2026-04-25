import sys
import subprocess
sys.path.insert(0, ".")
from pathlib import Path
from cli.control.ask import build_full_prompt


def test_build_full_prompt_no_skill():
    assert build_full_prompt("write the ADR", None) == "write the ADR"


def test_build_full_prompt_with_namespaced_skill():
    assert build_full_prompt("write the ADR", "octopus:doc-adr") == "/octopus:doc-adr write the ADR"


def test_build_full_prompt_with_bare_skill():
    assert build_full_prompt("scan auth/", "audit-security") == "/octopus:audit-security scan auth/"


def test_dry_run_exits_zero():
    result = subprocess.run(
        [sys.executable, "-m", "cli.control.ask", "writer", "write ADR", "--dry-run"],
        capture_output=True, text=True
    )
    assert result.returncode == 0
    assert "dry-run" in result.stdout


def test_dry_run_prints_role_and_task():
    result = subprocess.run(
        [sys.executable, "-m", "cli.control.ask", "backend-developer", "scan auth/", "--dry-run"],
        capture_output=True, text=True
    )
    assert "backend-developer" in result.stdout
    assert "scan auth/" in result.stdout
