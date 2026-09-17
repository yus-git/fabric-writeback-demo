import ast
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UUID_PATTERN = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-"
    r"[89ab][0-9a-f]{3}-[0-9a-f]{12}\b",
    re.IGNORECASE,
)
SOURCE_EXTENSIONS = {".json", ".md", ".py", ".sql"}


def check_python() -> list[str]:
    errors = []
    for path in ROOT.rglob("*.py"):
        if ".git" in path.parts:
            continue
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except (OSError, SyntaxError, UnicodeError) as error:
            errors.append(f"Python parse failed: {path.relative_to(ROOT)}: {error}")
    return errors


def check_json() -> list[str]:
    errors = []
    for path in ROOT.rglob("*.json"):
        if ".git" in path.parts:
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError, UnicodeError) as error:
            errors.append(f"JSON parse failed: {path.relative_to(ROOT)}: {error}")
    return errors


def check_portability() -> list[str]:
    errors = []
    obsolete_credential_name = "".join(("FabricAPI", "Credential"))
    prohibited_terms = (obsolete_credential_name,)
    zero_uuid = "00000000-0000-0000-0000-000000000000"

    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in SOURCE_EXTENSIONS:
            continue
        if ".git" in path.parts:
            continue
        relative = path.relative_to(ROOT)
        if relative == Path("tests/validate_repo.py"):
            continue
        text = path.read_text(encoding="utf-8")
        for term in prohibited_terms:
            if term in text:
                errors.append(f"Prohibited environment value in {relative}: {term}")
        if UUID_PATTERN.search(text.replace(zero_uuid, "")):
            errors.append(f"Unexpected UUID literal in {relative}")
    return errors


def check_required_files() -> list[str]:
    required = [
        "README.md",
        "docs/sql-database-pattern.md",
        "docs/lakehouse-pattern.md",
        "docs/limitations.md",
        "docs/microsoft-learn.md",
        "scripts/sql/01-create-database-objects.sql",
        "fabric-items/EmployeeWritebackFunctions.UserDataFunction/function_app.py",
        "fabric-items/EmployeeWriteback2.UserDataFunction/function_app.py",
        "fabric-items/Apply_Employee_Lakehouse_Writeback.Notebook/notebook-content.py",
    ]
    return [f"Missing required file: {path}" for path in required if not (ROOT / path).is_file()]


def main() -> int:
    errors = check_required_files() + check_python() + check_json() + check_portability()
    if errors:
        print("Repository validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Repository validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())