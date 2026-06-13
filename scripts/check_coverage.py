#!/usr/bin/env python3
"""Summarize `xcrun xccov view --report --json` output and optionally gate on a floor.

Usage:
    check_coverage.py <coverage.json> [min_app_coverage_percent]

Prints per-target line coverage, then the app-target coverage. Exits non-zero
only when a floor is supplied (> 0) and the app target falls below it.
"""

from __future__ import annotations

import json
import sys


def _pct(target: dict) -> float:
    return float(target.get("lineCoverage", 0.0)) * 100.0


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: check_coverage.py <coverage.json> [min_percent]", file=sys.stderr)
        return 2

    floor = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0

    with open(sys.argv[1], encoding="utf-8") as handle:
        report = json.load(handle)

    targets = report.get("targets", [])
    if not targets:
        print("No coverage targets found in report.")
        return 0

    print("Coverage by target:")
    app_pct: float | None = None
    for target in targets:
        name = target.get("name", "<unknown>")
        pct = _pct(target)
        covered = target.get("coveredLines", 0)
        executable = target.get("executableLines", 0)
        print(f"  {name}: {pct:5.1f}%  ({covered}/{executable} lines)")
        if "cursorSpeedometer" in name and "Tests" not in name:
            app_pct = pct

    if app_pct is None:
        app_pct = _pct(targets[0])

    print(f"\nApp line coverage: {app_pct:.1f}%  (floor: {floor:.1f}%)")

    if floor > 0 and app_pct + 1e-9 < floor:
        print(f"::error::Coverage {app_pct:.1f}% is below the required floor {floor:.1f}%")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
