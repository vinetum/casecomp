import { useState } from "react";
import {
  ArrowRight,
  CheckCheck,
  Download,
  ShieldCheck,
  TriangleAlert,
  Users,
} from "lucide-react";
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { Bootstrap, Decision } from "./types";
const names: Record<number, string> = {
  38: "Front End",
  92: "Merchandising",
  95: "Pharmacy",
};
const usd = (n: number) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 2,
  }).format(n);
const percent = (n: number | null) =>
  n == null ? "Closed" : `${(n * 100).toFixed(1)}%`;
export const scenes = [
  {
    title: "Start with the expected week",
    short: "BASE",
    verb: "Forecast",
    talk: "Find the service risk in the original draft. Use qualified capacity where the model estimates it matters.",
    cue: "Expected demand · official workforce pools",
  },
  {
    title: "Demand rises. The plan responds.",
    short: "PEAK",
    verb: "Optimize",
    talk: "The promotion and weather scenario applies the official demand multipliers. Recompute staffing rather than repeating the draft.",
    cue: "Same workforce · increased official demand",
  },
  {
    title: "A feasible plan can still carry risk.",
    short: "DISRUPT",
    verb: "Guard",
    talk: "Illness reduces capacity. A lower-bound model plateau is not permission to cut real coverage; the certificate separates workforce feasibility from service risk.",
    cue: "BASE demand · reduced official workforce",
  },
  {
    title: "Who gets the last worker?",
    short: "LAST WORKER",
    verb: "Reallocate",
    talk: "Compare the recipient’s gain with the lender’s loss. A cheap transfer can destroy more value than it creates.",
    cue: "Balanced priority · one eligible employee · lender opportunity cost",
  },
  {
    title: "Make the trade-off explicit.",
    short: "DECIDE & EXPORT",
    verb: "Evaluate",
    talk: "Inspect the feasible frontier. Export the audited plan for every official scenario, with its limitations in view.",
    cue: "567 rows · independently checked · official Service First export",
  },
];
export function WorkerDecision({ decision }: { decision: Decision }) {
  const [chosen, setChosen] = useState(0);
  const options = decision.last_worker.alternatives;
  const best = decision.last_worker.recommendation;
  const selected = options[Math.min(chosen, Math.max(0, options.length - 1))];
  const transfer = options.find((o) => o.donor !== null);
  return (
    <section className="worker-story" aria-label="Marginal employee decision">
      <div className="story-heading">
        <span className="eyebrow">THE LAST WORKER · MODEL ESTIMATES</span>
        <h3>The Last Worker</h3>
        <h2>
          {best
            ? `Assign eligible capacity to ${names[best.recipient]}`
            : "Keep the current allocation"}
        </h2>
        <p>{decision.last_worker.reason}</p>
      </div>
      <div className="worker-choices">
        <div className="worker-choice recommended">
          <span className="choice-tag">
            <CheckCheck size={16} />{" "}
            {best ? "Recommended addition" : "No beneficial change"}
          </span>
          {best ? (
            <>
              <h3>
                {best.donor ? names[best.donor] : "Unused qualified capacity"}{" "}
                <ArrowRight size={20} /> {names[best.recipient]}
              </h3>
              <div className="choice-numbers">
                <span>
                  Recipient gain
                  <strong>+{(best.recipient_gain * 100).toFixed(2)} pp</strong>
                </span>
                <span>
                  Lender effect
                  <strong>{(best.donor_effect * 100).toFixed(2)} pp</strong>
                </span>
                <span>
                  Extra block cost<strong>{usd(best.incremental_cost)}</strong>
                </span>
              </div>
              <p>
                {best.donor
                  ? "The lender loss is included in the net calculation."
                  : "No department gives up a scheduled worker. The addition draws on unused eligible capacity."}
              </p>
            </>
          ) : (
            <p>
              A service-maximized plan may have no positive one-worker
              improvement. The engine does not force a dramatic move.
            </p>
          )}
        </div>
        <div className="worker-choice rejected">
          <span className="choice-tag">
            <TriangleAlert size={16} />{" "}
            {transfer
              ? "Test the borrowing alternative"
              : "Qualification guardrail"}
          </span>
          {transfer ? (
            <>
              <h3>
                {names[transfer.donor!]} <ArrowRight size={20} />{" "}
                {names[transfer.recipient]}
              </h3>
              <div className="choice-numbers">
                <span>
                  Recipient gain
                  <strong>
                    {(transfer.recipient_gain * 100).toFixed(2)} pp
                  </strong>
                </span>
                <span>
                  Lender effect
                  <strong>{(transfer.donor_effect * 100).toFixed(2)} pp</strong>
                </span>
                <span>
                  Net expected targets
                  <strong>
                    {transfer.net_expected_targets_gain.toFixed(4)}
                  </strong>
                </span>
              </div>
              <p>
                {transfer.net_expected_targets_gain < 0
                  ? "Reject this transfer: the modeled lender loss outweighs the recipient gain."
                  : "A feasible transfer; compare its net gain and cost with the recommendation."}
              </p>
            </>
          ) : (
            <p>
              No partner transfer preserves the current staffing minimums and
              qualified capacity. Pharmacy never shares workers.
            </p>
          )}
        </div>
      </div>
      {selected && (
        <>
          <div
            className="option-picker"
            aria-label="Inspect eligible worker alternatives"
          >
            {options.map((o, i) => (
              <button
                key={i}
                aria-pressed={i === chosen}
                onClick={() => setChosen(i)}
              >
                {o.donor ? `${names[o.donor]} → ` : "Add to "}
                {names[o.recipient]}
              </button>
            ))}
          </div>
          <div className="impact-columns">
            {decision.plan.allocations.map((before) => {
              const after = selected.allocations.find(
                (a) => a.dept_id === before.dept_id,
              )!;
              return (
                <div key={before.dept_id}>
                  <strong>{names[before.dept_id]}</strong>
                  <span>
                    {before.employees} → {after.employees} employees
                  </span>
                  <div className="impact-track">
                    <i
                      style={{ width: `${(before.probability ?? 0) * 100}%` }}
                    />
                    <b
                      style={{ width: `${(after.probability ?? 0) * 100}%` }}
                    />
                  </div>
                  <small>
                    Target probability {percent(before.probability)} →{" "}
                    {percent(after.probability)}
                  </small>
                </div>
              );
            })}
          </div>
          <p className="tiny">
            Gray = current plan · green = inspected alternative. pp = percentage
            points. Net expected targets sums changes across departments; it is
            not a causal effect.
          </p>
        </>
      )}
    </section>
  );
}
export function CapacityCertificate({ decision }: { decision: Decision }) {
  return (
    <section className="capacity-certificate">
      <div className="certificate-stamp">
        <ShieldCheck size={25} />
        <div>
          <span className="eyebrow">FEASIBILITY CERTIFICATE</span>
          <h3>Feasibility Certificate</h3>
          <p>
            {decision.certificate.independent_verification.valid
              ? "Workforce constraints verified"
              : "Minimum staffing conflict"}
          </p>
        </div>
        <span>{decision.certificate.status}</span>
      </div>
      <div className="capacity-rows">
        {decision.plan.allocations.map((a, i) => {
          const lent = i < 2 ? decision.plan.allocations[1 - i].flex : 0;
          const committed = a.regular + lent;
          return (
            <div className="capacity-row" key={a.dept_id}>
              <div>
                <strong>{a.department}</strong>
                <span>
                  {committed} / {a.available_regular} regular pool committed
                </span>
              </div>
              <div
                className="capacity-rail"
                role="meter"
                aria-label={`${a.department} regular pool committed`}
                aria-valuemin={0}
                aria-valuemax={Math.max(1, a.available_regular)}
                aria-valuenow={committed}
              >
                <i
                  style={{
                    width: `${a.available_regular ? (100 * a.regular) / a.available_regular : 0}%`,
                  }}
                />
                <b
                  style={{
                    width: `${a.available_regular ? (100 * lent) / a.available_regular : 0}%`,
                  }}
                />
              </div>
              <p>
                {a.regular} local · {lent} lent · {a.flex} borrowed ·{" "}
                {a.overtime} / {a.overtime_cap} overtime
              </p>
              <span
                className={
                  a.probability != null && a.probability < 0.95
                    ? "risk-label"
                    : "safe-label"
                }
              >
                {a.is_open
                  ? `${percent(a.probability)} modeled target probability${a.minimum_shortfall ? ` · ${a.minimum_shortfall} below minimum` : ""}`
                  : "Closed · zero staffing"}
              </span>
            </div>
          );
        })}
      </div>
      <p className="tiny">
        Green = local regular · gold = lent from the same pool. Borrowed workers
        are counted only at their assignment. Feasible staffing does not
        guarantee service; standalone maxima compete for shared workers.
      </p>
    </section>
  );
}
export function DemoStage({
  step,
  decision,
  boot,
  onDownload,
}: {
  step: number;
  decision: Decision;
  boot: Bootstrap;
  onDownload: () => void;
}) {
  const scene = scenes[step];
  const draftMean =
    decision.draft.allocations
      .filter((a) => a.probability !== null)
      .reduce((sum, a) => sum + (a.probability ?? 0), 0) /
    decision.plan.allocations.filter((a) => a.is_open).length;
  return (
    <div className="demo-stage" data-demo-step={step}>
      <div className="scene-heading">
        <div>
          <span className="eyebrow">
            FORGE / {scene.verb.toUpperCase()} · SIMULATED CASE
          </span>
          <h2>{scene.title}</h2>
          <p>{scene.cue}</p>
        </div>
        <div className="scene-location">
          Warehouse {decision.selection.store_id}
          <strong>
            {decision.selection.day_date} · {decision.selection.shift_code}
          </strong>
          <span>{decision.selection.mode}</span>
        </div>
      </div>
      {step < 3 && (
        <>
          <div className="demo-metrics">
            <div>
              <span>Projected block labor cost</span>
              <strong>{usd(decision.plan.cost)}</strong>
              <small>
                {usd(decision.plan.cost - decision.draft.cost)} versus
                hypothetical draft
              </small>
            </div>
            <div>
              <span>Modeled target attainment</span>
              <strong>{percent(decision.plan.service)}</strong>
              <small>
                {((decision.plan.service - draftMean) * 100).toFixed(1)} pp
                versus draft · mean of open departments
              </small>
            </div>
            <div>
              <span>Independent workforce check</span>
              <strong>
                {decision.certificate.independent_verification.valid
                  ? "Feasible"
                  : "Conflict"}
              </strong>
              <small>
                {decision.draft.valid
                  ? "Draft also respects workforce limits"
                  : "Original draft is non-executable"}
              </small>
            </div>
          </div>
          <div className="department-cards">
            {decision.plan.allocations.map((a) => {
              const original = decision.draft.allocations.find(
                (d) => d.dept_id === a.dept_id,
              )!;
              return (
                <article key={a.dept_id}>
                  <span className="eyebrow">{a.department}</span>
                  <div className="headcount-change">
                    <span>
                      {a.draft_employees}
                      <small>Draft</small>
                    </span>
                    <ArrowRight />
                    <strong>
                      {a.employees}
                      <small>Recommended</small>
                    </strong>
                  </div>
                  <div className="service-transition">
                    <span>Target probability</span>
                    <strong>
                      {percent(original.probability)} → {percent(a.probability)}
                    </strong>
                  </div>
                  <p>
                    {a.regular} regular · {a.flex} borrowed flex · {a.overtime}{" "}
                    overtime
                  </p>
                  <div
                    className={
                      a.probability != null && a.probability < 0.95
                        ? "department-warning"
                        : "department-good"
                    }
                  >
                    {a.probability == null
                      ? "Closed block"
                      : a.probability <= 0.005
                        ? "Model at lower bound · staffing cuts need operational review"
                        : a.probability < 0.95
                          ? "Residual modeled service risk"
                          : "95% diagnostic threshold reached"}
                  </div>
                </article>
              );
            })}
          </div>
          {step === 2 && <CapacityCertificate decision={decision} />}
        </>
      )}
      {step === 3 && <WorkerDecision decision={decision} />}
      {step === 4 && (
        <>
          <div className="demo-close-grid">
            <CapacityCertificate decision={decision} />
            <section className="demo-frontier">
              <span className="eyebrow">PROJECTED COST / MODELED SERVICE</span>
              <h3>Every point is a feasible alternative.</h3>
              <div className="chart">
                <ResponsiveContainer>
                  <LineChart
                    data={decision.frontier.map((p) => ({
                      cost: p.cost,
                      service: p.service * 100,
                    }))}
                  >
                    <CartesianGrid vertical={false} />
                    <XAxis
                      dataKey="cost"
                      type="number"
                      domain={["dataMin", "dataMax"]}
                      tickFormatter={usd}
                    />
                    <YAxis
                      domain={["auto", "auto"]}
                      tickFormatter={(v) => `${v}%`}
                    />
                    <Tooltip
                      formatter={(v, n) =>
                        n === "service"
                          ? `${Number(v).toFixed(2)}%`
                          : usd(Number(v))
                      }
                    />
                    <Line
                      isAnimationActive={false}
                      dataKey="service"
                      stroke="#087e74"
                      strokeWidth={3}
                      dot={{ r: 5 }}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
              <p>
                Selected block · nondominated among eight solved tolerances.
                Service and cost remain model estimates.
              </p>
              <button className="primary full" onClick={onDownload}>
                <Download size={18} /> Download {boot.validation.rows}-row
                official plan
              </button>
              <small>
                Official Service First export for all scenarios. The Balanced
                demonstration does not overwrite it.
              </small>
            </section>
          </div>
          <div className="assumption-ribbon">
            <strong>What this decision knows</strong>
            <span>
              Qualified aggregate capacity. Audited costs. Forecast uncertainty.
            </span>
            <strong>What it cannot promise</strong>
            <span>
              Guaranteed waits, causal effects, an individual employee roster,
              or a validated holiday uplift.
            </span>
          </div>
        </>
      )}
      <div className="presenter-cue">
        <span>THE MANAGEMENT TAKEAWAY</span>
        <p>{scene.talk}</p>
      </div>
    </div>
  );
}
