import argparse
from pathlib import Path
import sys
import re

def fatal(message):
    print(message, file=sys.stderr)
    exit(1)

def configure(uconfig_path, definitions):
    print("---- scripts/configure-icu.py ----")
    print("Configuring ICU with the following definitions:")
    for (name, value) in definitions:
        print(f"  {name} = {value}")

    print("configuring...")

    # read in uconfig.h
    if not uconfig_path.exists():
        fatal(f"{uconfig_path} doesn't exist")

    with open(uconfig_path, "r") as f:
        uconfig_source = f.read()

    # wipe out any existing definitions placed by a previous configuration
    existing_definitions_match = re.search(r"^#define __UCONFIG_H__$\n\n((^#define \w+ .*$\n)+)", uconfig_source, flags=re.RegexFlag.MULTILINE)
    if existing_definitions_match != None:
        (start, end) = existing_definitions_match.span(1)
        uconfig_source = uconfig_source[:start] + uconfig_source[end:]

    # generate new definitions
    definitions_block = "\n".join([f"#define {name} {value}" for (name, value) in definitions])

    # insert new definitions into header file
    insertion_point_match = re.search(r"^#define __UCONFIG_H__$\n", uconfig_source, flags=re.RegexFlag.MULTILINE)
    if insertion_point_match == None:
        fatal("Couldn't insert ICU configuration definitions into uconfig.h")
    insertion_point = insertion_point_match.end()
    uconfig_source = uconfig_source[:insertion_point] + f"\n{definitions_block}" + uconfig_source[insertion_point:]

    # write new config back out to uconfig.h
    with open(uconfig_path, "w") as f:
        f.write(uconfig_source)

    print("done!")
    print("----------------------------------")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("uconfig_path")
    parser.add_argument("definitions", nargs="*", type=lambda s: tuple(s.split("=")))
    args = parser.parse_args()
    configure(Path(args.uconfig_path), args.definitions)

if __name__ == "__main__":
    main()
