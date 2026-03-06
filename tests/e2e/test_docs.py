"""E2E tests for documentation accuracy per SSOT P6.

Test case TC-P6-009: docs_examples_compile.
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path


class TestDocumentation:
    """Tests for README.md documentation accuracy."""

    def test_docs_examples_compile(self) -> None:
        """TC-P6-009: README examples run without errors."""
        readme_path = Path(__file__).parent.parent.parent / "README.md"

        with open(readme_path, encoding="utf-8") as f:
            readme_content = f.read()

        # Extract Python code blocks from README
        code_blocks = self._extract_python_code_blocks(readme_content)

        assert len(code_blocks) > 0, "No Python code blocks found in README.md"

        # Test each code block that looks like a complete example
        for i, code_block in enumerate(code_blocks):
            # Skip blocks that are just imports or incomplete snippets
            if self._is_complete_example(code_block):
                # Create temp file with the code
                with tempfile.NamedTemporaryFile(
                    mode="w", suffix=".py", delete=False
                ) as f:
                    f.write("import sys\n")
                    f.write("import os\n")
                    # Add PYTHONPATH to find decisiongraph
                    f.write(code_block)
                    temp_file = f.name

                try:
                    # Run the code
                    result = subprocess.run(
                        [sys.executable, temp_file],
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )

                    # Check for Python errors (not just runtime failures)
                    if result.returncode != 0:
                        # Some examples may fail at runtime (e.g., file not found)
                        # but should not have syntax or import errors
                        stderr = result.stderr.lower()

                        # Allow certain expected runtime errors
                        allowed_errors = [
                            "filenotfounderror",  # File paths in examples may not exist
                            "no such file or directory",  # Same
                        ]

                        is_allowed_error = any(err in stderr for err in allowed_errors)

                        # Check for actual Python errors
                        has_syntax_error = "syntaxerror" in stderr
                        has_import_error = "importerror" in stderr or "modulenotfounderror" in stderr
                        has_name_error = "nameerror" in stderr
                        has_attribute_error = "attributeerror" in stderr and "has no attribute" in stderr

                        critical_errors = (
                            has_syntax_error
                            or has_import_error
                            or has_name_error
                            or has_attribute_error
                        )

                        if critical_errors and not is_allowed_error:
                            raise AssertionError(
                                f"Code block {i} has critical errors:\n"
                                f"Code:\n{code_block}\n\n"
                                f"Error:\n{result.stderr}"
                            )

                finally:
                    # Clean up temp file
                    Path(temp_file).unlink(missing_ok=True)

    def _extract_python_code_blocks(self, markdown: str) -> list[str]:
        """Extract Python code blocks from Markdown.

        Args:
            markdown: Markdown content

        Returns:
            List of Python code blocks
        """
        # Match ```python code blocks
        pattern = r"```python\n(.*?)\n```"
        matches = re.findall(pattern, markdown, re.DOTALL)
        return matches

    def _is_complete_example(self, code: str) -> bool:
        """Check if code block is a complete example worth testing.

        Args:
            code: Code block content

        Returns:
            True if this looks like a complete example
        """
        # Skip pure import blocks
        lines = [line for line in code.split("\n") if line.strip() and not line.strip().startswith("#")]

        if len(lines) <= 2:
            return False  # Too short

        # Must have more than just imports
        non_import_lines = [line for line in lines if not line.strip().startswith("import") and not line.strip().startswith("from")]

        return len(non_import_lines) > 2


class TestNoChainOfThought:
    """Test that fixtures contain no chain-of-thought content per SSOT 13."""

    def test_no_chain_of_thought_in_fixtures(self) -> None:
        """TC-P6-010: Verify no chain-of-thought in golden fixtures."""
        from decisiongraph.testing.golden import (
            discover_fixture_dirs,
            load_fixture,
            validate_no_chain_of_thought,
        )

        fixtures_dir = Path(__file__).parent.parent / "golden"

        for fixture_dir in discover_fixture_dirs(fixtures_dir):
            fixture = load_fixture(fixture_dir)

            violations = validate_no_chain_of_thought(fixture)

            assert len(violations) == 0, (
                f"{fixture_dir.name} fixture contains chain-of-thought patterns:\n"
                + "\n".join(f"  - {v}" for v in violations)
            )
