#!/usr/bin/env python3

import re
import subprocess
import sys

BASE_VARIANTS = {
    "8",
    "11",
    "17",
}

VARIANTS = {
    "ORACLE8",
    "ZULU7",
    "ZULU8",
    "ZULU11",
    "IBM8",
    "SEMERU8",
    "SEMERU11",
    "SEMERU17",
    "GRAALVM11",
    "GRAALVM17",
}


def render(tpl, variant):
    res = tpl
    if variant:
        variant_upper = variant.upper()
        variant_lower = variant.lower()
        res = res.replace("<variant_name_upper/>", variant_upper)
        res = res.replace("<variant_name_lower/>", variant_lower)
        res = re.sub(r"^# <base>.*?^# </base>", "", res, flags=re.DOTALL | re.MULTILINE)
    else:
        res = re.sub(
            r"^# <variant>.*?^# </variant>", "", res, flags=re.DOTALL | re.MULTILINE
        )
    return res


with open("Dockerfile.tpl") as f:
    tpl = f.read()

with open("Dockerfile.base", "w") as f:
    f.write(render(tpl, None))

for variant in VARIANTS:
    with open(f"Dockerfile.{variant.lower()}", "w") as f:
        f.write(render(tpl, variant))


def run(args, raise_on_status=True):
    print(f"Running: {args}")
    result = subprocess.run(args, capture_output=True)
    print(f"Standard output: {result.stdout}")
    print(f"Standard error: {result.stderr}")
    if raise_on_status:
        if result.returncode != 0:
            raise Exception(f"Command: {args} exited with code {result.returncode}")
    return result


if "--push" in sys.argv:
    print("Pushing images")
    base_branch = run(["git", "branch", "--show-current"]).stdout.strip()
    for variant in VARIANTS + BASE_VARIANTS:
        variant = variant.lower()
        print(f"Pushing {variant}")
        run(["git", "checkout", base_branch])
        if (
            run(
                ["git", "rev-parse", "--verify", variant], raise_on_status=False
            ).returncode
            == 0
        ):
            run(["git", "branch", "-D", variant])
        run(["git", "checkout", "-b", variant])
        run(["ln", "-sf", f"Dockerfile.{variant}", "Dockerfile"])
        run(["git", "commit", "-m", f"Update symlink for {variant}", "Dockerfile"])
        run(["git", "push", "origin", f"+{variant}:{variant}"])
    run(["git", "checkout", base_branch])
