#!/usr/bin/env python3
"""Checks the alert rules still match what US-007 AC3 requires.

Alert thresholds get loosened during busy weeks, for good reasons at the time,
and nobody remembers to tighten them again. The acceptance criteria named
specific numbers -- p99 over 2s, 5xx over 1%, payment failures -- so those
numbers are asserted here and a change to them fails the build.

This validates the definition, not the deployment. Nothing here proves an alert
would fire: no Prometheus is running and the API emits no metrics. See the note
at the top of infra/observability/alerts.yaml.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip3 install pyyaml")

ALERTS = Path(__file__).resolve().parent.parent / "infra" / "observability" / "alerts.yaml"

# alert name -> (substring that must appear in its expression, why)
REQUIRED = {
    "JyotishApiLatencyP99": ("> 2", "AC3 requires alerting when p99 exceeds 2s"),
    "JyotishApiErrorRate": ("> 0.01", "AC3 requires alerting when 5xx exceeds 1%"),
    "JyotishPaymentFailureRate": ("payment_attempts_total", "AC3 requires payment failure alerting"),
    # US-008 AC3.
    "JyotishCrashFreeRate": ("< 99.0", "US-008 AC3 requires alerting below 99% crash-free"),
    # Not from AC3, but the rule that makes the rest trustworthy.
    "JyotishMetricsAbsent": ("absent(", "the deadman switch must survive edits"),
}


def main() -> int:
    if not ALERTS.exists():
        print(f"FAIL: {ALERTS} is missing", file=sys.stderr)
        return 1

    document = yaml.safe_load(ALERTS.read_text())
    rules = {
        rule["alert"]: rule
        for group in document.get("groups", [])
        for rule in group.get("rules", [])
        if "alert" in rule
    }

    failures: list[str] = []

    for name, (needle, why) in REQUIRED.items():
        rule = rules.get(name)
        if rule is None:
            failures.append(f"{name} is missing -- {why}")
            continue
        expression = " ".join(str(rule.get("expr", "")).split())
        if needle not in expression:
            failures.append(
                f"{name} no longer contains '{needle}' -- {why}\n    expr: {expression}"
            )

    # Every alert must point somewhere actionable. An alert that pages someone
    # at 03:00 with no runbook is worse than no alert.
    for name, rule in rules.items():
        if not rule.get("annotations", {}).get("runbook"):
            failures.append(f"{name} has no runbook annotation")
        if not rule.get("labels", {}).get("severity"):
            failures.append(f"{name} has no severity label")

    if failures:
        print("Alert rule checks failed:\n", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print(f"Alert rules OK: {len(rules)} rules, AC3 thresholds intact.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
