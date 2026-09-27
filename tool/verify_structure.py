#!/usr/bin/env python3
"""
Structural verification for the SaveWise Flutter project.

There is no Dart SDK in this sandbox, so this stands in for `flutter analyze`.
It cannot type-check, but it catches the class of mistake that actually happens
when writing a large app across many files: a reference to a member that does
not exist, an import that does not resolve, an import left behind after the
code that needed it was removed, and unbalanced delimiters.

Checks
  1. every import resolves to a real file (relative and `package:savewise/...`)
  2. delimiters balance in each file (strings/comments stripped first)
  3. `Klass.member` references against members declared on that class
  4. `state.member` / `_state.member` references against AppState's API
  5. imports that contribute no referenced symbol
  6. declared-but-unreferenced private widget classes
  7. constructor calls: unknown named arguments, and missing required ones
  8. project types referenced without importing the library that declares them
  9. switch expressions over project enums that miss a value and have no default
 10. instance members on explicitly typed locals, against their class
 11. extension members used without importing the library that declares them
"""

from __future__ import annotations

import os
import re
import sys
from collections import defaultdict

ROOT = os.environ.get(
    "SAVEWISE_ROOT", "/sessions/great-festive-cerf/mnt/outputs/savewise"
)
LIB = os.path.join(ROOT, "lib")


# ----------------------------------------------------------------- strip pass

def strip_code(src: str) -> str:
    """Remove comments and string bodies so regexes cannot match inside them."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            depth, i = 1, i + 2
            while i < n and depth:
                if src[i] == "/" and src[i + 1 : i + 2] == "*":
                    depth, i = depth + 1, i + 2
                elif src[i] == "*" and src[i + 1 : i + 2] == "/":
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
            continue

        if c in "'\"":
            # triple-quoted?
            triple = src[i : i + 3]
            if triple in ("'''", '"""'):
                i += 3
                while i < n and src[i : i + 3] != triple:
                    i += 2 if src[i] == "\\" else 1
                i += 3
                out.append('""')
                continue
            quote, i = c, i + 1
            while i < n and src[i] != quote:
                if src[i] == "\\":
                    i += 2
                    continue
                # keep ${...} interpolation, it contains real code
                if src[i] == "$" and src[i + 1 : i + 2] == "{":
                    depth, i = 1, i + 2
                    start = i
                    while i < n and depth:
                        if src[i] == "{":
                            depth += 1
                        elif src[i] == "}":
                            depth -= 1
                        i += 1
                    out.append(" " + src[start : i - 1] + " ")
                    continue
                i += 1
            i += 1
            out.append('""')
            continue

        out.append(c)
        i += 1
    return "".join(out)


# ------------------------------------------------------------------ inventory

dart_files: dict[str, str] = {}
for base, _dirs, names in os.walk(ROOT):
    if "/build/" in base or "/.dart_tool/" in base:
        continue
    for name in names:
        if name.endswith(".dart"):
            path = os.path.join(base, name)
            with open(path, encoding="utf-8") as handle:
                dart_files[path] = handle.read()

stripped = {path: strip_code(src) for path, src in dart_files.items()}

problems: list[str] = []
notes: list[str] = []


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT)


# ------------------------------------------------- 1. imports resolve to files

# Imports must be read from the RAW source: strip_code() blanks string bodies,
# so the stripped text says `import "";` and the path is gone. Anchoring to the
# line start keeps doc comments that mention an import out of the results.
IMPORT_RE = re.compile(r"^\s*import\s+'([^']+)'", re.M)
PACKAGE_SELF = "package:savewise/"


def resolve_import(path: str, target: str) -> str | None:
    """Absolute path an import points at, or None if it leaves the project.

    `test/` uses absolute `package:savewise/...` imports (relative ones across
    the lib boundary are an analyzer error), so both forms must resolve.
    """
    if target.startswith(PACKAGE_SELF):
        return os.path.normpath(os.path.join(LIB, target[len(PACKAGE_SELF):]))
    if target.startswith("package:") or target.startswith("dart:"):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(path), target))


imports: dict[str, list[str]] = {}

for path, src in dart_files.items():
    found = IMPORT_RE.findall(src)
    imports[path] = found
    for target in found:
        resolved = resolve_import(path, target)
        if resolved is None:
            continue
        if resolved not in dart_files:
            problems.append(f"{rel(path)}: unresolved import '{target}'")


# --------------------------------------------------------- 2. delimiters match

PAIRS = {")": "(", "]": "[", "}": "{"}
for path, src in stripped.items():
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in src:
        if ch == "\n":
            line += 1
        elif ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack:
                problems.append(f"{rel(path)}:{line}: stray '{ch}'")
                break
            open_ch, open_line = stack.pop()
            if open_ch != PAIRS[ch]:
                problems.append(
                    f"{rel(path)}:{line}: '{ch}' closes '{open_ch}' "
                    f"opened at line {open_line}"
                )
                break
    else:
        if stack:
            open_ch, open_line = stack[-1]
            problems.append(
                f"{rel(path)}: unclosed '{open_ch}' from line {open_line}"
            )


# ------------------------------------- 3. declared members of our own classes

# Anything declared at class scope: fields, getters, methods, constants.
MEMBER_PATTERNS = [
    re.compile(r"^\s*(?:static\s+)?(?:const|final|late)?\s*[\w<>,?\s\[\]().]*?\bget\s+(\w+)"),
    re.compile(r"^\s*static\s+(?:const|final)\s+[\w<>,?\s\[\]().]+?\s(\w+)\s*="),
    re.compile(r"^\s*static\s+[\w<>,?\s\[\]().]+?\s(\w+)\s*[({<]"),
    # static field with no const/final, incl. function types: `static void Function(int)? f;`
    re.compile(r"^\s*static\s+.*?\b(\w+)\s*(?:=|;)\s*$"),
    # factory and named constructors: `factory PayCycle.forDate(`, `Bill.fromJson(`
    re.compile(r"^\s*(?:factory\s+)?[A-Z]\w*\.(\w+)\s*\("),
    re.compile(r"^\s*(?:final|const|late\s+final|late)\s+[\w<>,?\s\[\]().]+?\s(\w+)\s*[=;,)]"),
    # Methods. The return type must allow nested generics and a trailing `?`,
    # otherwise `List<Map<String, dynamic>> getMapList(` and `Map<String,
    # dynamic>? getMap(` both read as undeclared.
    re.compile(
        r"^\s*(?:@override\s+)?(?:static\s+)?"
        r"(?:Future<[\w<>,?\s\[\]]*>\??|void|int|double|bool|String|num"
        r"|[A-Z]\w*(?:<[\w<>,?\s\[\]]*>)?\??)"
        r"\s+(\w+)\s*\("
    ),
]

CLASS_RE = re.compile(
    r"^(?:abstract\s+final\s+|abstract\s+|final\s+|sealed\s+|mixin\s+)?"
    r"(?:class|enum|extension|typedef)\s+(\w+)",
    re.M,
)

class_members: dict[str, set[str]] = defaultdict(set)
class_file: dict[str, str] = {}
enum_values: dict[str, set[str]] = defaultdict(set)
declared_types: set[str] = set()
type_owner: dict[str, str] = {}

for path, src in stripped.items():
    lines = src.split("\n")
    current: str | None = None
    depth = 0
    is_enum = False
    for raw in lines:
        match = CLASS_RE.match(raw)
        if match and depth == 0:
            current = match.group(1)
            declared_types.add(current)
            type_owner.setdefault(current, path)
            class_file.setdefault(current, path)
            is_enum = raw.lstrip().startswith("enum") or " enum " in raw
        if current:
            for pattern in MEMBER_PATTERNS:
                found = pattern.match(raw)
                if found:
                    class_members[current].add(found.group(1))
            if is_enum and depth == 1:
                for value in re.findall(r"\b([a-z]\w*)\s*(?:,|;|\()", raw):
                    enum_values[current].add(value)
        depth += raw.count("{") + raw.count("(") - raw.count("}") - raw.count(")")
        if depth <= 0:
            depth = 0
            current = None
            is_enum = False


# ------------------------------------------------------- extension bookkeeping
#
# Extension members are the one thing that is invisible to every other check
# here, because the code never writes the extension's name: you call
# `grade.label`, not `HealthGradeX(grade).label`. Dart still requires the
# declaring library to be imported for the member to be in scope, so a missing
# import produces an `undefined_getter` that nothing textual gives away.
# Track which file declares which extension member, in both directions.

extension_names = {
    name
    for name, owner in class_file.items()
    if re.search(rf"^extension\s+{re.escape(name)}\b", stripped[owner], re.M)
}

ext_members_by_file: dict[str, set[str]] = defaultdict(set)
ext_member_files: dict[str, set[str]] = defaultdict(set)
for name in extension_names:
    if name.startswith("_"):
        continue
    for member in class_members[name]:
        if member.startswith("_"):
            continue
        ext_members_by_file[class_file[name]].add(member)
        ext_member_files[member].add(class_file[name])

# Snapshot this BEFORE the grafting step below copies extension members onto
# their target type. Afterwards every extension member also looks like a plain
# class member, which would make check 11 consider them all undecidable and
# quietly do nothing — the exact failure mode the self-test exists to catch.
non_extension_members: set[str] = set()
for owner_name, owned in class_members.items():
    if owner_name in extension_names:
        continue
    non_extension_members |= owned

for name, values in enum_values.items():
    class_members[name] |= values

# Extensions declared `extension X on Y` graft members onto Y.
for path, src in stripped.items():
    for ext_name, target in re.findall(r"extension\s+(\w+)\s+on\s+(\w+)", src):
        class_members[target] |= class_members.get(ext_name, set())

# Static-only helper classes are the ones worth checking hard: a typo in
# `AppConstants.x` is silent until compile time.
STATIC_CLASSES = [
    "AppConstants", "AppColors", "AppTextStyles", "AppTheme", "Money", "Dates",
    "J", "StorageKeys", "LocalStore", "ShellNav", "ShellTab", "AppSheet",
    "ReminderEngine", "BudgetEngine", "GoalEngine", "HealthScoreEngine",
    "EmergencyFundEngine", "ChallengeEngine", "AchievementEngine",
    "CalculatorEngine", "AdvisorEngine", "PayCycle", "AchievementCatalog",
    "ChallengePool", "AmountField", "DayOfMonthField", "ProfileSheets",
    "BillSheets", "GoalSheets", "ExpenseSheets", "FundSheets",
]

for path, src in stripped.items():
    for klass in STATIC_CLASSES:
        if klass not in class_members or klass not in src:
            continue
        for member in re.findall(rf"\b{klass}\.(\w+)", src):
            if member in class_members[klass]:
                continue
            if member in {"values", "new", "length", "toString", "hashCode"}:
                continue
            problems.append(
                f"{rel(path)}: {klass}.{member} is not declared on {klass}"
            )


# --------------------------------------------------- 4. AppState surface check

state_members = class_members.get("AppState", set())
for path, src in stripped.items():
    if path.endswith("app_state.dart"):
        continue
    for var in ("state", "_state", "appState"):
        for member in re.findall(rf"\b{var}[!]?\.(\w+)", src):
            if member in state_members:
                continue
            if member in {
                "addListener", "removeListener", "notifyListeners", "dispose",
                "hasListeners", "runtimeType", "toString", "hashCode",
            }:
                continue
            problems.append(
                f"{rel(path)}: AppState has no member '{member}' "
                f"(used as {var}.{member})"
            )


# ------------------------------------------------------- 5. unused own imports

for path, src in stripped.items():
    body = IMPORT_RE.sub("", src)
    for target in imports[path]:
        resolved = resolve_import(path, target)
        if resolved is None or resolved not in dart_files:
            continue
        exported = {
            name
            for name in CLASS_RE.findall(stripped[resolved])
            if not name.startswith("_")
        }
        exported |= {
            name
            for name in re.findall(
                r"^(?:const|final)\s+[\w<>,?\s]*\s(\w+)\s*=", stripped[resolved], re.M
            )
            if not name.startswith("_")
        }
        # An import can be earning its keep purely through an extension member,
        # e.g. importing health_score_engine.dart only so `grade.label` resolves.
        exported |= ext_members_by_file.get(resolved, set())
        if not exported:
            continue
        if not any(re.search(rf"\b{re.escape(name)}\b", body) for name in exported):

            notes.append(f"{rel(path)}: import '{target}' appears unused")


# ------------------------------------------- 6. private classes never rendered

for path, src in stripped.items():
    private = [n for n in CLASS_RE.findall(src) if n.startswith("_")]
    for name in private:
        # An `extension _FooX on Foo` is referenced through its target's members,
        # never by name, so a single occurrence is expected.
        if re.search(rf"extension\s+{re.escape(name)}\s+on\b", src):
            continue
        uses = len(re.findall(rf"\b{re.escape(name)}\b", src))
        if uses <= 1:
            notes.append(f"{rel(path)}: private class {name} is never used")


# ------------------------------------------ 7. constructor named-argument check

def call_args(src: str, start: int) -> list[str] | None:
    """Named argument labels at the top nesting level of a call starting at `(`."""
    depth, i, n = 0, start, len(src)
    labels: list[str] = []
    segment_start = start + 1
    while i < n:
        ch = src[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                chunk = src[segment_start:i]
                found = re.match(r"\s*(\w+)\s*:(?!:)", chunk)
                if found:
                    labels.append(found.group(1))
                return labels
        elif ch == "," and depth == 1:
            chunk = src[segment_start:i]
            found = re.match(r"\s*(\w+)\s*:(?!:)", chunk)
            if found:
                labels.append(found.group(1))
            segment_start = i + 1
        i += 1
    return None


# Keyed by (scope, constructor). `scope` is None for public classes and the
# declaring file for private ones: `_Chip` in three different files is three
# unrelated types, because Dart privacy is per-library, and conflating them
# invents parameter mismatches that do not exist.
ctor_params: dict[tuple[str | None, str], set[str]] = {}
ctor_required: dict[tuple[str | None, str], set[str]] = {}
decl_spans: dict[str, list[tuple[int, int]]] = defaultdict(list)

SPLIT_PARAMS = re.compile(r",(?![^(<]*[)>])")


def paren_end(src: str, open_paren: int) -> int | None:
    depth, i, n = 0, open_paren, len(src)
    while i < n:
        if src[i] in "([{":
            depth += 1
        elif src[i] in ")]}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


# Parse declarations only in the file that declares the class, and only where
# the parameter list actually looks like a declaration (`this.` / `super.` /
# `required`). Otherwise a collection literal like `AchievementProgress(def: d)`
# gets mistaken for a declaration and poisons the known-parameter set.
for path, src in stripped.items():
    for name in set(CLASS_RE.findall(src)):
        private = name.startswith("_")
        if not private and path != class_file.get(name):
            continue
        scope = path if private else None
        for match in re.finditer(
            rf"(?:^|\n)\s*(?:const\s+|factory\s+)?({re.escape(name)}(?:\.\w+)?)\s*\(", src
        ):
            full = match.group(1)
            open_paren = match.end() - 1
            end = paren_end(src, open_paren)
            if end is None:
                continue
            params = src[open_paren + 1 : end]
            if not re.search(r"\bthis\.|\bsuper\.|\brequired\b", params):
                continue
            decl_spans[path].append((match.start(), end))
            known = ctor_params.setdefault((scope, full), set())
            needed = ctor_required.setdefault((scope, full), set())
            if "{" not in params:
                continue
            block = params[params.find("{") + 1 :]
            for piece in SPLIT_PARAMS.split(block):
                piece = piece.strip().rstrip("}").strip()
                if not piece:
                    continue
                label = re.search(r"(\w+)\s*(?:=|$)", piece)
                if not label:
                    continue
                known.add(label.group(1))
                if re.match(r"required\b", piece):
                    needed.add(label.group(1))

for path, src in stripped.items():
    spans = decl_spans.get(path, [])
    for (scope, full), known in ctor_params.items():
        if not known or (scope is not None and scope != path):
            continue
        if full not in src:
            continue
        for match in re.finditer(rf"(?<![\w.]){re.escape(full)}\s*\(", src):
            if any(start <= match.start() <= end for start, end in spans):
                continue
            labels = call_args(src, match.end() - 1)
            if labels is None:
                continue
            for label in labels:
                if label not in known:
                    problems.append(
                        f"{rel(path)}: {full}(...) has no parameter '{label}'"
                    )
            missing = ctor_required[(scope, full)] - set(labels)
            if missing:
                problems.append(
                    f"{rel(path)}: {full}(...) missing required "
                    f"{', '.join(sorted(missing))}"
                )


# ------------------------------- 8. project types used without importing them

# Dart imports are not transitive: referencing a type means directly importing
# the library that declares it. This is the mistake that hides easiest.
owners: dict[str, set[str]] = defaultdict(set)
for path, src in stripped.items():
    for name in CLASS_RE.findall(src):
        if not name.startswith("_"):
            owners[name].add(path)

for path, src in stripped.items():
    visible: set[str] = {path}
    for target in imports[path]:
        resolved = resolve_import(path, target)
        if resolved is not None and resolved in dart_files:
            visible.add(resolved)
    body = IMPORT_RE.sub("", src)
    for name, declaring in owners.items():
        if declaring & visible:
            continue
        if name not in body:
            continue
        if re.search(rf"\b{re.escape(name)}\b", body):
            where = ", ".join(sorted(rel(p) for p in declaring))
            problems.append(
                f"{rel(path)}: uses {name} but does not import it (declared in {where})"
            )


# ------------------------------------- 9. switch expressions over project enums

enum_bodies: dict[str, set[str]] = {}
for path, src in stripped.items():
    for match in re.finditer(r"\benum\s+(\w+)\s*(?:implements[^{]*|with[^{]*)?\{", src):
        end = paren_end(src, match.end() - 1)
        if end is None:
            continue
        body = src[match.end() : end]
        head = body.split(";")[0]
        values: set[str] = set()
        for piece in SPLIT_PARAMS.split(head):
            found = re.match(r"\s*([a-z]\w*)", piece)
            if found:
                values.add(found.group(1))
        if values:
            enum_bodies[match.group(1)] = values

for path, src in stripped.items():
    for match in re.finditer(r"\bswitch\s*\(", src):
        subject_end = paren_end(src, match.end() - 1)
        if subject_end is None:
            continue
        brace = src.find("{", subject_end)
        if brace < 0 or src[subject_end + 1 : brace].strip() not in ("", ")"):
            continue
        block_end = paren_end(src, brace)
        if block_end is None:
            continue
        block = src[brace + 1 : block_end]
        if re.search(r"(?:^|[\s(])_\s*=>|\bdefault\s*:", block):
            continue
        hits = re.findall(r"\b([A-Z]\w*)\.(\w+)\s*(?:=>|:)", block)
        if not hits:
            continue
        prefixes = {p for p, _ in hits}
        for prefix in prefixes:
            if prefix not in enum_bodies:
                continue
            covered = {v for p, v in hits if p == prefix}
            uncovered = enum_bodies[prefix] - covered
            if uncovered:
                line = src[: match.start()].count("\n") + 1
                problems.append(
                    f"{rel(path)}:{line}: switch on {prefix} does not cover "
                    f"{', '.join(sorted(uncovered))}"
                )


# ------------------------- 10. instance members on explicitly typed locals

# This codebase always writes the type out (`final EmiResult r = ...`), which
# makes a cheap version of type checking possible: resolve the variable's class
# and look the member up. Restricted to classes that extend nothing, so no
# inherited member can be mistaken for a typo, and to variable names with a
# single declared type in the file, so scopes cannot be confused.
OBJECT_MEMBERS = {
    "toString", "hashCode", "runtimeType", "noSuchMethod",
    "values", "name", "index", "call",
}

subclass: set[str] = set()
for path, src in stripped.items():
    for match in re.finditer(
        r"^(?:abstract\s+|final\s+|sealed\s+|base\s+|mixin\s+)*class\s+(\w+)[^{]*",
        src,
        re.M,
    ):
        if re.search(r"\b(?:extends|implements|with)\b", match.group(0)):
            subclass.add(match.group(1))

# Enums carry generated members and every value; treat them as opaque here.
plain_classes = {
    name
    for name in class_members
    if name not in subclass and name not in enum_bodies and not name.startswith("_")
}

TYPE_RE = r"[A-Z]\w*(?:<[^<>()]*>)?"

# Every place a name is bound to a written-out type: locals, for-in loops, and
# parameters (including closure parameters). All three must be collected, not
# just locals — `bills.where((Bill b) => ...)` and `map.entries.map((MapEntry e)
# => ...)` reuse the same short names, and missing one of them would attribute
# `e.key` to the wrong class.
BIND_PATTERNS = [
    re.compile(rf"\b(?:final|const|late\s+final|late)\s+({TYPE_RE})\??\s+(\w+)\s*[=;]"),
    re.compile(rf"\bfor\s*\(\s*(?:final\s+)?({TYPE_RE})\??\s+(\w+)\s+in\b"),
    re.compile(rf"[(,]\s*(?:required\s+)?({TYPE_RE})\??\s+(\w+)\s*(?=[,)=])"),
    # Bare mutable locals: `SavingsChallenge updated = ...;`. Without this the
    # name looks untyped here and a binding from elsewhere in the file gets
    # blamed for members it never had.
    re.compile(rf"^\s+({TYPE_RE})\??\s+(\w+)\s*[=;]", re.M),
]

for path, src in stripped.items():
    typed: dict[str, set[str]] = defaultdict(set)
    for pattern in BIND_PATTERNS:
        for match in pattern.finditer(src):
            typed[match.group(2)].add(match.group(1))
    for var_name, types in typed.items():
        if len(types) != 1:
            continue
        type_name = next(iter(types))
        if type_name not in plain_classes:
            continue
        members = class_members[type_name]
        for member in set(re.findall(rf"\b{re.escape(var_name)}[!?]?\.(\w+)", src)):
            if member in members or member in OBJECT_MEMBERS:
                continue
            problems.append(
                f"{rel(path)}: {type_name} has no member '{member}' "
                f"(used as {var_name}.{member})"
            )


# ------------------------------------- 11. extension member without its import
#
# Narrow on purpose. A bare `.label` cannot be attributed: ten extensions in
# this project declare `label`, and it is a member of half the Flutter widget
# library besides. So only flag member names that are decidable from text
# alone — declared by exactly one project extension, declared by no project
# class, and not a name the SDK is likely to own. `label`, `color` and `icon`
# fall outside that and stay the real analyzer's job.

SDK_LIKELY_MEMBERS = {
    "label", "color", "icon", "name", "id", "index", "value", "values",
    "weight", "style", "size", "title", "text", "child", "children",
    "length", "isEmpty", "isNotEmpty", "first", "last", "keys", "day",
}

undecidable: set[str] = {m for m, owners in ext_member_files.items() if len(owners) > 1}
undecidable |= non_extension_members

decidable = {
    member: next(iter(owners))
    for member, owners in ext_member_files.items()
    if member not in undecidable and member not in SDK_LIKELY_MEMBERS
}

for path, src in stripped.items():
    own_imports = {resolve_import(path, target) for target in imports[path]}
    for member in set(re.findall(r"\.\s*(\w+)", src)):
        declared_in = decidable.get(member)
        if declared_in is None or declared_in == path or declared_in in own_imports:
            continue
        problems.append(
            f"{rel(path)}: uses .{member} but does not import "
            f"{rel(declared_in)}, which declares the extension providing it"
        )


# --------------------------------------------------------------------- report
print(f"scanned {len(dart_files)} dart files\n")

if problems:
    print(f"PROBLEMS ({len(problems)})")
    for item in sorted(set(problems)):
        print("  x", item)
else:
    print("PROBLEMS: none")

if notes:
    print(f"\nNOTES ({len(set(notes))})")
    for item in sorted(set(notes)):
        print("  -", item)

sys.exit(1 if problems else 0)
