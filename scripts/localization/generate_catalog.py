#!/usr/bin/env python3
"""Generates RaVqnat/Resources/Localizable.xcstrings and InfoPlist.xcstrings from strings.py.

Usage:
  python3 scripts/localization/generate_catalog.py            # write catalogs
  python3 scripts/localization/generate_catalog.py --check DERIVED_DATA
      # verify every key the compiler extracted (from a build's .stringsdata) is translated
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from strings import DYNAMIC_FAMILIES, INFO_PLIST, STRINGS, VERBATIM  # noqa: E402

RESOURCES = os.path.join(ROOT, "RaVqnat", "Resources")
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f)")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def specifiers(text):
    return sorted(re.sub(r"\d+\$", "", s) for s in SPECIFIER.findall(text))


def build_catalog():
    dynamic = {prefix + member for prefix, members in DYNAMIC_FAMILIES.items() for member in members}
    strings = {}
    for key, entry in sorted(STRINGS.items()):
        en, ka = entry[0], entry[1]
        localizations = {"ka": unit(ka)}
        if len(entry) > 2:
            localizations["en"] = {"variations": {"plural": {"one": unit(entry[2]), "other": unit(en)}}}
        else:
            localizations["en"] = unit(en)
        record = {"localizations": localizations}
        if key in dynamic:
            record = {"extractionState": "manual", **record}
        strings[key] = record
    for key in VERBATIM:
        strings[key] = {"shouldTranslate": False}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def build_info_plist_catalog():
    strings = {key: {"extractionState": "manual", "localizations": {"en": unit(en), "ka": unit(ka)}}
               for key, (en, ka) in INFO_PLIST.items()}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def validate():
    problems = []
    for key, entry in STRINGS.items():
        en, ka = entry[0], entry[1]
        if not ka.strip():
            problems.append(f"missing Georgian: {key}")
        if specifiers(en) != specifiers(ka):
            problems.append(f"format specifiers differ: {key}")
        if specifiers(key) and specifiers(key) != specifiers(en):
            problems.append(f"key/value specifiers differ: {key}")
    for prefix, members in DYNAMIC_FAMILIES.items():
        for member in members:
            if prefix + member not in STRINGS:
                problems.append(f"missing dynamic key: {prefix}{member}")
    return problems


def check_extracted(derived_data):
    files = glob.glob(os.path.join(derived_data, "**", "RaVqnat.build", "**", "*.stringsdata"), recursive=True)
    if not files:
        return [f"no .stringsdata found under {derived_data} (build first)"]
    used = set()
    for path in files:
        with open(path) as handle:
            for entries in json.load(handle).get("tables", {}).values():
                used.update(entry["key"] for entry in entries)
    known = set(STRINGS) | set(VERBATIM)
    return [f"untranslated key used in code: {key}" for key in sorted(used - known)]


def write(path, catalog):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")


def main():
    problems = validate()
    if "--check" in sys.argv:
        problems += check_extracted(sys.argv[sys.argv.index("--check") + 1])
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if "--check" not in sys.argv:
        write(os.path.join(RESOURCES, "Localizable.xcstrings"), build_catalog())
        write(os.path.join(RESOURCES, "InfoPlist.xcstrings"), build_info_plist_catalog())
        print(f"Wrote {len(STRINGS) + len(VERBATIM)} strings (en, ka).")
    else:
        print("Localization check passed.")


if __name__ == "__main__":
    main()
