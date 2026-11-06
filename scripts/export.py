import argparse
from backend.engine import Engine
from backend.data import OUT, write_json
from backend.verify import validate_submission

p = argparse.ArgumentParser()
p.add_argument("--team-id", default="SHIFTWISE")
args = p.parse_args()
e = Engine()
t = e.submission(args.team_id)
t.to_csv(OUT / "TEAM_SUBMISSION_COMPLETED.csv", index=False)
v = validate_submission(t)
write_json(OUT / "validation_report.json", v)
print("Forecast selection:", e.forecast.metrics)
print("Scenario summaries:", e.summary)
print("Submission validation:", v)
if not v["valid"]:
    raise SystemExit(1)
