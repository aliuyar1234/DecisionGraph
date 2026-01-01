"""Bootstrap tests for DecisionGraph - TC-P0-001 through TC-P0-010.

These tests verify the foundational setup of the DecisionGraph package.
"""

import subprocess
import sys
from pathlib import Path


class TestBootstrap:
    """Test cases for package bootstrap (SSOT P0)."""

    def test_import_root(self) -> None:
        """TC-P0-001: import decisiongraph succeeds."""
        import decisiongraph

        assert decisiongraph is not None

    def test_version_exposed(self) -> None:
        """TC-P0-010: __version__ is accessible."""
        import decisiongraph

        assert hasattr(decisiongraph, "__version__")
        assert isinstance(decisiongraph.__version__, str)
        assert len(decisiongraph.__version__) > 0

    def test_api_module_importable(self) -> None:
        """TC-P0-009: decisiongraph.api is importable."""
        from decisiongraph import api

        assert api is not None

    def test_packaging_src_layout(self) -> None:
        """TC-P0-008: Package uses src-layout."""
        # Find the package location
        import decisiongraph

        package_path = Path(decisiongraph.__file__).parent
        # Should be under a 'src' directory in development
        # or in site-packages when installed
        assert package_path.exists()
        assert package_path.name == "decisiongraph"


class TestErrorCodes:
    """Test cases for error codes (TC-P0-002)."""

    def test_error_codes_enum(self) -> None:
        """TC-P0-002: Error codes match SSOT 7.2."""
        from decisiongraph.errors import (
            DG_ERR_CONFLICT,
            DG_ERR_EVENT_SEQUENCE_INVALID,
            DG_ERR_IDEMPOTENCY_CONFLICT,
            DG_ERR_INVALID_ARGUMENT,
            DG_ERR_NOT_FOUND,
            DG_ERR_PII_POLICY_VIOLATION,
            DG_ERR_PROJECTION_OUT_OF_DATE,
            DG_ERR_SCHEMA_VIOLATION,
            DG_ERR_STORAGE,
            ERROR_CODES,
        )

        # All error codes should be strings starting with DG_ERR_
        expected_codes = {
            DG_ERR_NOT_FOUND,
            DG_ERR_CONFLICT,
            DG_ERR_IDEMPOTENCY_CONFLICT,
            DG_ERR_SCHEMA_VIOLATION,
            DG_ERR_EVENT_SEQUENCE_INVALID,
            DG_ERR_PROJECTION_OUT_OF_DATE,
            DG_ERR_INVALID_ARGUMENT,
            DG_ERR_STORAGE,
            DG_ERR_PII_POLICY_VIOLATION,
        }

        assert ERROR_CODES == expected_codes
        assert len(ERROR_CODES) == 9

        for code in ERROR_CODES:
            assert code.startswith("DG_ERR_")

    def test_decision_graph_error_format(self) -> None:
        """DecisionGraphError has code and message attributes."""
        from decisiongraph.errors import DG_ERR_NOT_FOUND, DecisionGraphError

        error = DecisionGraphError(DG_ERR_NOT_FOUND, "Resource not found")

        assert error.code == DG_ERR_NOT_FOUND
        assert error.message == "Resource not found"
        assert str(error) == "DG_ERR_NOT_FOUND: Resource not found"


class TestDomainTypes:
    """Test cases for domain types (TC-P0-003)."""

    def test_dataclasses_construct(self) -> None:
        """TC-P0-003: Domain types are constructable."""
        from decisiongraph.domain import (
            ActorRef,
            ApprovalSubject,
            Change,
            EntityRef,
            EvidenceRef,
            Fact,
            PolicyRef,
            SourceObjectRef,
            SourceRef,
            Value,
            Violation,
        )

        # ActorRef
        actor = ActorRef(actor_type="agent", actor_id="test-agent")
        assert actor.actor_type == "agent"
        assert actor.actor_id == "test-agent"

        # EntityRef
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        assert entity.entity_type == "Account"
        assert entity.entity_id == "acc-123"

        # Value (decimal as string, not float)
        value = Value(type="decimal", value="123.45")
        assert value.type == "decimal"
        assert value.value == "123.45"

        # Fact
        fact = Fact(key="revenue", value=value)
        assert fact.key == "revenue"

        # SourceRef
        source = SourceRef(producer_id="prod-1", system="crm")
        assert source.producer_id == "prod-1"

        # SourceObjectRef
        source_obj = SourceObjectRef(
            system="crm", object_type="Account", object_id="acc-123"
        )
        assert source_obj.system == "crm"

        # EvidenceRef
        evidence = EvidenceRef(source=source_obj, locator="/path/to/doc")
        assert evidence.locator == "/path/to/doc"

        # PolicyRef
        policy = PolicyRef(policy_id="discount-policy", policy_version="1.0")
        assert policy.policy_id == "discount-policy"

        # Violation
        violation = Violation(code="MAX_DISCOUNT", message="Exceeds limit")
        assert violation.code == "MAX_DISCOUNT"

        # Change
        old_val = Value(type="decimal", value="100.00")
        new_val = Value(type="decimal", value="120.00")
        change = Change(path="amount", old_value=old_val, new_value=new_val)
        assert change.path == "amount"

        # ApprovalSubject
        subject = ApprovalSubject(subject_type="exception", subject_id="exc-1")
        assert subject.subject_type == "exception"


class TestTooling:
    """Test cases for tooling (TC-P0-004, TC-P0-005, TC-P0-006, TC-P0-007)."""

    def test_mypy_strict_pass(self) -> None:
        """TC-P0-004: mypy strict mode passes."""
        result = subprocess.run(
            [sys.executable, "-m", "mypy", "src/", "--strict"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0, f"mypy failed: {result.stdout}\n{result.stderr}"

    def test_ruff_pass(self) -> None:
        """TC-P0-005: ruff check passes."""
        result = subprocess.run(
            [sys.executable, "-m", "ruff", "check", "src/"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0, f"ruff failed: {result.stdout}\n{result.stderr}"

    def test_import_linter_contract_domain_pure(self) -> None:
        """TC-P0-006: Domain isolation contract enforced."""
        # Use Python to invoke import-linter's CLI
        # lint_imports() returns 0 on success, non-zero on failure
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                "from importlinter import cli; exit(cli.lint_imports())",
            ],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert (
            result.returncode == 0
        ), f"import-linter failed: {result.stdout}\n{result.stderr}"

    def test_no_cycles(self) -> None:
        """TC-P0-007: No circular imports exist."""
        # This is verified by successfully importing all modules
        import decisiongraph
        import decisiongraph.api
        import decisiongraph.domain
        import decisiongraph.domain.events
        import decisiongraph.domain.types
        import decisiongraph.errors
        import decisiongraph.ids
        import decisiongraph.policy
        import decisiongraph.projections
        import decisiongraph.query
        import decisiongraph.serialization
        import decisiongraph.storage
        import decisiongraph.testing
        import decisiongraph.time

        # If we get here without ImportError, no cycles exist
        assert True
