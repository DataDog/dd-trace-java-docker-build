#!/usr/bin/env python3

import re


VARIANTS={
    "8",
    "11",
    "17",
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
        res = re.sub(r'^# <base>.*?^# </base>', '', res, flags=re.DOTALL|re.MULTILINE)
    else:
        res = re.sub(r'^# <variant>.*?^# </variant>', '', res, flags=re.DOTALL|re.MULTILINE)
    return res

with open('Dockerfile.tpl') as f:
    tpl = f.read()

with open('Dockerfile.base', 'w') as f:
    f.write(render(tpl, None))

for variant in VARIANTS:
    with open(f"Dockerfile.{variant}", 'w') as f:
        f.write(render(tpl, variant))
