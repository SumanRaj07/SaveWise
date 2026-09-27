#!/usr/bin/env python3
"""
Self-test for verify_structure.py.

A checker that cannot fail is worthless. This copies the project to a scratch
directory, injects one deliberate fault at a time, and asserts the checker
reports it. Every check earns its clean run.

Run:  python3 tool/verify_selftest.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.dirname(HERE)
CHECKER = os.path.join(HERE, "verify_structure.py")


def run(root: str) -> str:
    env = dict(os.environ, SAVEWISE_ROOT=root)
    done = subprocess.run(
        [sys.executable, CHECKER], env=env, capture_output=True, text=True
    )
    return done.stdout + done.stderr


def fresh_copy() -> str:
    root = tempfile.mkdtemp(prefix="savewise-selftest-")
    target = os.path.join(root, "savewise")
    shutil.copytree(
        SOURCE,
        target,
        ignore=shutil.ignore_patterns("build", ".dart_tool", ".git"),
    )
    return target


def patch(root: str, relative: str, old: str, new: str) -> None:
    path = os.path.join(root, relative)
    with open(path, encoding="utf-8") as handle:
        src = handle.read()
    if old not in src:
        raise AssertionError(f"fixture drifted: {old!r} not found in {relative}")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(src.replace(old, new, 1))


def drop_line(root: str, relative: str, needle: str) -> None:
    path = os.path.join(root, relative)
    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()
    kept = [line for line in lines if needle not in line]
    if len(kept) == len(lines):
        raise AssertionError(f"fixture drifted: no line matching {needle!r} in {relative}")
    with open(path, "w", encoding="utf-8") as handle:
        handle.writelines(kept)


def append(root: str, relative: str, text: str) -> None:
    with open(os.path.join(root, relative), "a", encoding="utf-8") as handle:
        handle.write(text)


# Each case: name, mutation, and a regex the report must contain.
CASES: list[tuple[str, object, str]] = [
    (
        "1 unresolved import",
        lambda root: patch(
            root,
            "lib/app.dart",
            "import 'core/theme/app_theme.dart';",
            "import 'core/theme/app_thmee.dart';",
        ),
        r"unresolved import 'core/theme/app_thmee\.dart'",
    ),
    (
        "2 unbalanced delimiter",
        lambda root: append(root, "lib/domain/engines/pay_cycle.dart", "\nclass Dangling {\n"),
        r"unclosed '\{'",
    ),
    (
        "3 unknown static member",
        lambda root: patch(
            root,
            "lib/screens/goals_screen.dart",
            "AppColors.emerald",
            "AppColors.emeraldish",
        ),
        r"AppColors\.emeraldish is not declared",
    ),
    (
        "4 unknown AppState member",
        lambda root: patch(
            root,
            "lib/screens/goals_screen.dart",
            "state.planFor(g.id)",
            "state.planForNothing(g.id)",
        ),
        r"AppState has no member 'planForNothing'",
    ),
    (
        "7a unknown named argument",
        lambda root: patch(
            root,
            "lib/screens/goals_screen.dart",
            "_GoalCard(goal: g, plan:",
            "_GoalCard(bogusParam: 1, goal: g, plan:",
        ),
        r"_GoalCard\(\.\.\.\) has no parameter 'bogusParam'",
    ),
    (
        "7b missing required argument",
        lambda root: patch(
            root,
            "lib/screens/goals_screen.dart",
            "_GoalCard(goal: g, plan: state.planFor(g.id))",
            "_GoalCard(goal: g)",
        ),
        r"_GoalCard\(\.\.\.\) missing required plan",
    ),
    (
        "8 type used without importing it",
        lambda root: drop_line(
            root,
            "lib/domain/engines/goal_engine.dart",
            "import '../../data/models/goal.dart';",
        ),
        r"uses Goal but does not import it",
    ),
    (
        "9 non-exhaustive switch over enum",
        lambda root: drop_line(
            root,
            "lib/domain/engines/achievement_engine.dart",
            "AchievementMetric.goalsCompleted =>",
        ),
        r"switch on AchievementMetric does not cover goalsCompleted",
    ),
    (
        "10 instance member typo on a typed local",
        lambda root: patch(
            root,
            "lib/domain/engines/reminder_engine.dart",
            "if (bill.paidMonths.contains(key)) return bill;",
            "if (bill.paidMonthsX.contains(key)) return bill;",
        ),
        r"Bill has no member 'paidMonthsX'",
    ),
    (
        "11 extension member without its declaring import",
        # formatters.dart imports only dart:math and intl, so a call to
        # BudgetCategoryX.defaultShare here has no way to resolve. Deliberately
        # untyped so nothing else can catch it — this is check 11 or nothing.
        lambda root: append(
            root,
            "lib/core/utils/formatters.dart",
            "\ndouble probeShare(dynamic c) => c.defaultShare;\n",
        ),
        r"uses \.defaultShare but does not import",
    ),
]


def main() -> int:
    baseline_root = fresh_copy()
    baseline = run(baseline_root)
    shutil.rmtree(os.path.dirname(baseline_root), ignore_errors=True)

    if "PROBLEMS: none" not in baseline:
        print("baseline is not clean, fix that before self-testing:\n")
        print(baseline)
        return 1
    print("baseline: clean\n")

    failures = 0
    for name, mutate, expected in CASES:
        root = fresh_copy()
        try:
            mutate(root)
            report = run(root)
            if re.search(expected, report):
                print(f"  caught  {name}")
            else:
                failures += 1
                print(f"  MISSED  {name}")
                print(f"          expected /{expected}/, report was:")
                for line in report.strip().split("\n"):
                    print(f"          | {line}")
        except AssertionError as err:
            failures += 1
            print(f"  BROKEN  {name}: {err}")
        finally:
            shutil.rmtree(os.path.dirname(root), ignore_errors=True)

    print()
    if failures:
        print(f"{failures} of {len(CASES)} checks did not fire — the checker is lying")
        return 1
    print(f"all {len(CASES)} checks fire on an injected fault")
    return 0


if __name__ == "__main__":
    sys.exit(main())
