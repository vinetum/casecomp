"""Standalone post-export audit; does not load models or import the solver."""

import argparse
import json
import pandas as pd
from backend.data import OUT
from backend.verify import validate_submission

p = argparse.ArgumentParser()
p.add_argument("path", nargs="?", default=str(OUT / "TEAM_SUBMISSION_COMPLETED.csv"))
args = p.parse_args()
result = validate_submission(pd.read_csv(args.path))
print(json.dumps(result, indent=2))
if not result["valid"]:
    raise SystemExit(1)
