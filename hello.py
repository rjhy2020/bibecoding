#!/usr/bin/env python3

"""
Simple hello CLI.

Usage:
  python3 hello.py [name]

Examples:
  python3 hello.py
  python3 hello.py Alice
"""

import sys


def greet(name: str | None = None) -> str:
    if not name:
        return "Hello from Codex CLI!"
    return f"Hello, {name}!"


def main(argv: list[str]) -> int:
    name = argv[1] if len(argv) > 1 else None
    print(greet(name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

