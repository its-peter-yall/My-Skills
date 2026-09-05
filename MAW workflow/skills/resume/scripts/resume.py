#!/usr/bin/env python3
"""
Workflow Resume Helper for MAW and MAW-lite
Discovers and validates resumable workflows containing state.md in the docs/ directory.
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path


def parse_state_metadata(state_path: Path) -> dict:
    """Extract metadata (objective name, workflow type, progress summary) from state.md."""
    metadata = {
        "objective": state_path.parent.name,
        "workflow": "unknown",
        "title": state_path.parent.name,
        "total_tasks": 0,
        "completed_tasks": 0,
        "in_progress_tasks": 0,
        "pending_tasks": 0,
        "last_updated": None,
    }

    try:
        content = state_path.read_text(encoding="utf-8")
    except Exception as e:
        metadata["error"] = f"Failed to read file: {e}"
        return metadata

    # 1. Parse YAML frontmatter if present
    frontmatter_match = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if frontmatter_match:
        fm_text = frontmatter_match.group(1)
        for line in fm_text.splitlines():
            if ":" in line:
                key, val = line.split(":", 1)
                key = key.strip().lower()
                val = val.strip().strip("'\"")
                if key == "workflow":
                    metadata["workflow"] = val.lower()
                elif key == "objective":
                    metadata["objective"] = val

    # 2. Fallback regex for workflow header if not in frontmatter
    if metadata["workflow"] == "unknown":
        wf_match = re.search(r"\b[Ww]orkflow\s*[:=]\s*([a-zA-Z0-9_-]+)", content)
        if wf_match:
            metadata["workflow"] = wf_match.group(1).lower()

    # 3. Detect workflow from file structure / content hints if still unknown
    if metadata["workflow"] == "unknown":
        if "Phase Hierarchy" in content or "maw-full" in content.lower():
            metadata["workflow"] = "maw-full"
        elif "Dependency Matrix" in content or "pipelined" in content.lower():
            metadata["workflow"] = "maw"

    # 4. Handle legacy workflow mappings
    if metadata["workflow"] == "maw-lite":
        metadata["workflow"] = "maw"
    elif metadata["workflow"] == "maw" and ("Phase Hierarchy" in content or "phase-1" in content):
        metadata["workflow"] = "maw-full"

    # 4. Count progress checkboxes
    completed = len(re.findall(r"-\s*\[x\]", content, re.IGNORECASE))
    in_progress = len(re.findall(r"-\s*\[#\]", content))
    pending = len(re.findall(r"-\s*\[ \]", content))

    metadata["completed_tasks"] = completed
    metadata["in_progress_tasks"] = in_progress
    metadata["pending_tasks"] = pending
    metadata["total_tasks"] = completed + in_progress + pending

    if metadata["total_tasks"] > 0:
        percent = int((completed / metadata["total_tasks"]) * 100)
        metadata["progress_percent"] = percent
    else:
        metadata["progress_percent"] = 0

    return metadata


def scan_docs_directory(docs_dir: Path) -> list:
    """Scan docs/ for all subdirectories containing state.md."""
    resumable_list = []
    if not docs_dir.exists() or not docs_dir.is_dir():
        return resumable_list

    for entry in sorted(docs_dir.iterdir()):
        if entry.is_dir():
            state_file = entry / "state.md"
            if state_file.exists() and state_file.is_file():
                meta = parse_state_metadata(state_file)
                meta["path"] = str(state_file.as_posix())
                resumable_list.append(meta)

    return resumable_list


def main():
    parser = argparse.ArgumentParser(description="Find resumable MAW workflows")
    parser.add_argument(
        "--objective",
        "-o",
        type=str,
        help="Specific objective name to resume",
        default=None,
    )
    parser.add_argument(
        "--docs-dir",
        "-d",
        type=str,
        help="Custom docs directory path (defaults to ./docs)",
        default=None,
    )
    args = parser.parse_args()

    cwd = Path.cwd()
    docs_dir = Path(args.docs_dir) if args.docs_dir else cwd / "docs"

    # Check if docs/ directory exists
    if not docs_dir.exists() or not docs_dir.is_dir():
        result = {
            "status": "error",
            "code": "DOCS_NOT_FOUND",
            "message": f"The 'docs/' directory was not found in '{cwd.as_posix()}'. No active or previous workflows exist.",
            "docs_path": str(docs_dir.as_posix()),
            "available_objectives": [],
        }
        print(json.dumps(result, indent=2))
        sys.exit(0)

    all_resumable = scan_docs_directory(docs_dir)

    if not all_resumable:
        result = {
            "status": "empty",
            "code": "NO_STATE_FILES",
            "message": f"The 'docs/' directory exists, but no subdirectories contain a 'state.md' file.",
            "docs_path": str(docs_dir.as_posix()),
            "available_objectives": [],
        }
        print(json.dumps(result, indent=2))
        sys.exit(0)

    # If user provided a specific objective
    if args.objective:
        target = args.objective.strip()
        matched = next((item for item in all_resumable if item["objective"].lower() == target.lower()), None)

        if matched:
            result = {
                "status": "found",
                "code": "OBJECTIVE_MATCHED",
                "message": f"Found resumable workflow for objective '{target}'.",
                "target": target,
                "workflow": matched["workflow"],
                "state_file": matched["path"],
                "metadata": matched,
                "available_objectives": all_resumable,
            }
        else:
            result = {
                "status": "not_found",
                "code": "OBJECTIVE_NOT_FOUND",
                "message": f"Objective '{target}' was not found with a valid state.md.",
                "target": target,
                "available_objectives": all_resumable,
            }
        print(json.dumps(result, indent=2))
        sys.exit(0)

    # No specific objective requested: return the list
    result = {
        "status": "list",
        "code": "SELECT_OBJECTIVE",
        "message": f"Found {len(all_resumable)} resumable workflow(s). Please choose an objective to resume.",
        "available_objectives": all_resumable,
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
