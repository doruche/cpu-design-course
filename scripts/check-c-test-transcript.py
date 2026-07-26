#!/usr/bin/env python3
"""Deterministic UART transcript oracle for the three CPU-driven C_TESTs."""

from __future__ import annotations

import argparse
import re
from decimal import Decimal
from pathlib import Path


def identity(text: str, test: int) -> str:
    match = re.match(
        rf"(?P<id>DEVELOPMENT|[0-9]{{8,12}}) Test #{test} - ", text)
    if not match:
        raise SystemExit("transcript has no valid build identity header")
    return match.group("id")


def check_exact(text: str, expected: str) -> None:
    if text != expected:
        limit = min(len(text), len(expected))
        offset = next((index for index in range(limit)
                       if text[index] != expected[index]), limit)
        raise SystemExit(
            f"transcript mismatch at byte {offset}: "
            f"got={text[offset:offset + 40]!r} "
            f"expected={expected[offset:offset + 40]!r}")


def check_test0(text: str) -> None:
    student = identity(text, 0)
    expected = (
        f"{student} Test #0 - UART simple test:\n\r"
        "<Phase 0> - Output test:\n\r"
        "Hello World!\n\r"
        "\n\r<Phase 1> - Input test:\n\r"
        "Enter a char: Input received: A\n\r"
        "Enter a char: Input received: B\n\r"
        "Test ended."
    )
    check_exact(text, expected)


def check_test1(text: str) -> None:
    student = identity(text, 1)
    expected = (
        f"{student} Test #1 - Formatted input/output test:\n\r"
        "<Phase 0> - Formatted output test:\n\r"
        "123\n\r0x456\n\rc\n\rHello World!\n\r98.765400\n\r"
        "\n\r<Phase 1> - Formatted input test:\n\r"
        "Enter an integer, a char, and a string (e.g., 123 x hello): \n\r"
        "-42 x hello\n\r"
        "Input received: int=-42, char='x', string=\"hello\"\n\r"
        "Enter an integer, a char, and a string (e.g., 123 x hello): \n\r"
        "7 q end\n\r"
        "Input received: int=7, char='q', string=\"end\"\n\r"
        "Test ended."
    )
    check_exact(text, expected)


def numbers(line: str) -> list[int]:
    return [int(value) for value in re.findall(r"-?[0-9]+", line)]


def check_test2(text: str) -> None:
    identity(text, 2)
    normalized = text.replace("\r", "")
    fixed = re.search(
        r"Sorted array:\n(?P<values>(?:-?[0-9]+ ){8})\n"
        r"Time consumed: (?P<time>[0-9]+\.[0-9]{6}) ms", normalized)
    if not fixed:
        raise SystemExit("fixed-size sort transcript is malformed")
    fixed_values = numbers(fixed.group("values"))
    if fixed_values != [-1, 0, 1, 2, 3, 5, 5, 8]:
        raise SystemExit(f"fixed-size sort mismatch: {fixed_values}")
    if Decimal(fixed.group("time")) <= 0:
        raise SystemExit("fixed-size timer did not advance")

    dynamic = re.search(
        r"array generated:\n(?P<generated>(?:[0-9]+ ){8})\n\n"
        r"Sorted array:\n(?P<sorted>(?:[0-9]+ ){8})\n\n"
        r"Time consumed: (?P<time>[0-9]+\.[0-9]{6}) ms\n\n"
        r"malloc released\.\n$", normalized)
    if not dynamic:
        raise SystemExit("dynamic sort/malloc transcript is malformed")
    generated = numbers(dynamic.group("generated"))
    sorted_values = numbers(dynamic.group("sorted"))
    if sorted_values != sorted(generated):
        raise SystemExit(
            f"dynamic sort is not a sorted permutation: {generated} -> {sorted_values}")
    if Decimal(dynamic.group("time")) <= 0:
        raise SystemExit("dynamic-sort timer did not advance")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("test", type=int, choices=(0, 1, 2))
    parser.add_argument("transcript", type=Path)
    args = parser.parse_args()

    text = args.transcript.read_bytes().decode("ascii")
    (check_test0, check_test1, check_test2)[args.test](text)
    print(f"c-test-{args.test} transcript: PASS ({len(text)} bytes)")


if __name__ == "__main__":
    main()
