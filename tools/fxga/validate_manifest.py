#!/usr/bin/env python3
"""Validate an FXGA module settings manifest before packaging a module.

Usage:
    python tools/fxga/validate_manifest.py path/to/fxga-settings.json
    python tools/fxga/validate_manifest.py --self-test
"""
import json
import re
import sys
from pathlib import Path

KEY = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,63}$")
CHOICE = re.compile(r"^[A-Za-z0-9_.:-]{1,48}$")


class SchemaError(ValueError):
    pass


def validate(document: dict) -> list[dict]:
    if not isinstance(document, dict) or type(document.get("schema")) is not int or document["schema"] != 1:
        raise SchemaError("schema must be integer 1")
    settings = document.get("settings")
    if not isinstance(settings, list) or len(settings) > 40:
        raise SchemaError("settings must be an array of at most 40 items")
    keys = set()
    for setting in settings:
        if not isinstance(setting, dict):
            raise SchemaError("each setting must be an object")
        key = setting.get("key")
        if not isinstance(key, str) or not KEY.fullmatch(key) or key in keys:
            raise SchemaError("invalid/duplicate setting key")
        keys.add(key)
        kind = setting.get("type")
        if kind not in ("toggle", "select", "integer"):
            raise SchemaError("unsupported type")
        label = setting.get("label", key)
        if not isinstance(label, str):
            raise SchemaError("label must be text")
        if kind == "toggle":
            if "default" in setting and type(setting["default"]) is not bool:
                raise SchemaError("toggle default must be boolean")
        elif kind == "select":
            choices = setting.get("options")
            if not isinstance(choices, list) or not 1 <= len(choices) <= 16:
                raise SchemaError("select must define 1-16 choices")
            if any(not isinstance(v, str) or not CHOICE.fullmatch(v) for v in choices):
                raise SchemaError("unsafe choice")
            if len(set(choices)) != len(choices):
                raise SchemaError("duplicate choice")
            if setting.get("default", choices[0]) not in choices:
                raise SchemaError("default choice is not listed")
        else:
            lower, upper = setting.get("min", -100000), setting.get("max", 100000)
            if type(lower) is not int or type(upper) is not int:
                raise SchemaError("bounds must be integers")
            if not (-100000 <= lower <= upper <= 100000):
                raise SchemaError("bounds out of range")
            default = setting.get("default", lower)
            if type(default) is not int or not lower <= default <= upper:
                raise SchemaError("integer default outside bounds")
    return settings


def self_test() -> None:
    valid = {"schema": 1, "settings": [
        {"key": "enabled", "type": "toggle", "default": True},
        {"key": "profile", "type": "select", "options": ["stable", "debug"]},
        {"key": "level", "type": "integer", "min": 0, "max": 3, "default": 1},
    ]}
    validate(valid)
    bad = [
        {"schema": 2, "settings": []},
        {"schema": 1, "settings": [{"key": "a/b", "type": "toggle"}]},
        {"schema": 1, "settings": [{"key": "x", "type": "select", "options": ["ok", "$(id)"]}]},
        {"schema": 1, "settings": [{"key": "x", "type": "integer", "min": 9, "max": 1}]},
        {"schema": 1, "settings": [{"key": "a", "type": "toggle"}, {"key": "a", "type": "toggle"}]},
    ]
    for case in bad:
        try:
            validate(case)
        except SchemaError:
            continue
        raise AssertionError("invalid example accepted")
    print("FXGA manifest self-tests passed (1 valid, 5 invalid)")


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        self_test()
        return 0
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    raw = path.read_bytes()
    if len(raw) > 65536:
        raise SchemaError("manifest exceeds 64 KiB limit")
    fields = validate(json.loads(raw.decode("utf-8")))
    print("OK: schema v1, " + str(len(fields)) + " settings: " +
          ", ".join(item["key"] for item in fields))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (SchemaError, ValueError, OSError) as error:
        print("INVALID: " + str(error), file=sys.stderr)
        sys.exit(1)
