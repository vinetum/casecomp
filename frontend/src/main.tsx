import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import {
  Activity,
  ArrowDownToLine,
  ArrowRight,
  BarChart3,
  Check,
  CheckCheck,
  ChevronRight,
  CircleHelp,
  Factory,
  Gauge,
  GitBranch,
  LayoutDashboard,
  LoaderCircle,
  Play,
  RefreshCw,
  ShieldCheck,
  SlidersHorizontal,
  Sparkles,
  TriangleAlert,
  Users,
  Zap,
} from "lucide-react";
import type { Allocation, Bootstrap, Decision, Selection } from "./types";
import "./styles.css";

const departments: Record<number, string> = {
  38: "Front End",
  92: "Merchandising",
  95: "Pharmacy",
};
const money = (x: number) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(x);
const pct = (x: number | null | undefined) =>
  x == null ? "Closed" : `${(x * 100).toFixed(1)}%`;
const date = (x: string) =>
  new Date(`${x}T12:00:00`).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
const tabs = [
  {
    name: "Command Center",
    icon: LayoutDashboard,
    caption: "Your week, in perspective",
  },
  {
    name: "Demand Intelligence",
    icon: BarChart3,
    caption: "Anticipate the pressure",
  },
  {
    name: "Staffing Optimizer",
    icon: Users,
    caption: "Put every worker where they matter",
  },
  {
    name: "Scenario Lab",
    icon: SlidersHorizontal,
    caption: "Prepare for what changes",
  },
  {
    name: "Decision & Export",
    icon: GitBranch,
    caption: "From insight to action",
  },
];
const initial: Selection = {
  scenario_id: 1,
  store_id: 2,
  day_date: "2026-02-14",
  shift_code: "MID",
  mode: "Service First",
  demand_factor: 1,
  availability_factor: 1,
  uncertainty: "central",
};
async function api<T>(url: string, init?: RequestInit): Promise<T> {
  const r = await fetch(url, init);
  if (!r.ok) throw new Error(`Request failed (${r.status}). ${await r.text()}`);
  return r.json();
}
function Badge({ ok, children }: { ok: boolean; children: React.ReactNode }) {
  return (
    <span className={`badge ${ok ? "good" : "warn"}`}>
      {ok ? <ShieldCheck size={13} /> : <TriangleAlert size={13} />} {children}
    </span>
  );
}
function App() {
  const [boot, setBoot] = useState<Bootstrap | null>(null),
    [decision, setDecision] = useState<Decision | null>(null),
    [selection, setSelection] = useState(initial),
    [department, setDepartment] = useState(38),
    [tab, setTab] = useState(0);
  const [loading, setLoading] = useState(true),
    [error, setError] = useState(""),
    [demand, setDemand] = useState(100),
    [availability, setAvailability] = useState(100),
    [stress, setStress] = useState<Selection["uncertainty"]>("central"),
    [log, setLog] = useState<string[]>([]),
    [team, setTeam] = useState("SHIFTWISE"),
    [tour, setTour] = useState(-1),
    [exportError, setExportError] = useState(""),
    [frontierIndex, setFrontierIndex] = useState(0);
  const sequence = useRef(0);
  useEffect(() => {
    api<Bootstrap>("/api/bootstrap")
      .then(setBoot)
      .catch((e) => {
        setError(String(e));
        setLoading(false);
      });
  }, []);
  useEffect(() => {
    if (!boot) return;
    const seq = ++sequence.current;
    setLoading(true);
    setError("");
    api<Decision>("/api/decision", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(selection),
    })
      .then((d) => {
        if (seq !== sequence.current) return;
        setDecision(d);
        setFrontierIndex(0);
        setLog((l) =>
          [
            `${["BASE", "PEAK", "DISRUPT"][selection.scenario_id - 1]} · W${selection.store_id} · ${date(selection.day_date)} ${selection.shift_code}: ${money(d.plan.cost)}, ${pct(d.plan.service)} modeled service`,
            ...l,
          ].slice(0, 5),
        );
      })
      .catch((e) => {
        if (seq === sequence.current) setError(String(e));
      })
      .finally(() => {
        if (seq === sequence.current) setLoading(false);
      });
  }, [boot, selection]);
  const change = (s: Partial<Selection>) =>
    setSelection((v) => ({ ...v, ...s }));
  const reset = () => {
    setDemand(100);
    setAvailability(100);
    setStress("central");
    change({
      demand_factor: 1,
      availability_factor: 1,
      uncertainty: "central",
    });
  };
  const advanceTour = () => {
    const next = (tour + 1) % 4;
    setTour(next);
    setTab(next === 3 ? 4 : next === 0 ? 0 : 3);
    setDemand(100);
    setAvailability(100);
    setStress("central");
    change({
      ...initial,
      scenario_id: next === 3 ? 3 : next + 1,
      day_date: next === 3 ? "2026-02-13" : "2026-02-14",
      shift_code: next === 3 ? "OPEN" : "MID",
    });
  };
  const download = async () => {
    setExportError("");
    try {
      const r = await fetch(`/api/export?team_id=${encodeURIComponent(team)}`);
      if (!r.ok)
        throw new Error(
          "Use a 1–64 character team ID starting with a letter or number; letters, numbers, spaces, hyphens and underscores only.",
        );
      const blob = await r.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "TEAM_SUBMISSION_COMPLETED.csv";
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setExportError(String(e));
    }
  };
  if (!boot)
    return (
      <div className="startup">
        <div className="brand large">
          <Activity /> SHIFTWISE
        </div>
        {error ? (
          <>
            <p role="alert">{error}</p>
            <button onClick={() => location.reload()}>Retry connection</button>
          </>
        ) : (
          <>
            <LoaderCircle className="spin" />
            <p>Loading the workforce decision engine…</p>
            <small>
              Auditing source data · validating forecasts · solving staffing
              plans
            </small>
          </>
        )}
      </div>
    );
  const weekly = boot.summary.find(
      (s) => s.scenario_id === selection.scenario_id,
    )!,
    a = decision?.plan.allocations.find((a) => a.dept_id === department),
    sm = boot.metrics.service[String(department)];
  const staffChart = boot.dates.map((day) => ({
    day: date(day),
    ...Object.fromEntries(
      [1, 2, 3].map((id) => [
        String(id),
        boot.allocations
          .filter(
            (a) =>
              a.scenario_id === id &&
              a.store_id === selection.store_id &&
              a.day_date === day,
          )
          .reduce((s, a) => s + a.employees, 0),
      ]),
    ),
  }));
  const hist = boot.historical
    .filter(
      (r) =>
        r.store_id === selection.store_id &&
        r.dept_id === department &&
        r.day_date >= "2026-01-22",
    )
    .map((r) => ({
      day: date(r.day_date),
      actual: r.daily_demand_units,
      forecast: undefined as number | undefined,
      benchmark: undefined as number | undefined,
      range: undefined as number[] | undefined,
    }));
  const future = boot.dates.map((day) => {
    const f = boot.forecasts.filter(
        (r) =>
          r.store_id === selection.store_id &&
          r.dept_id === department &&
          r.day_date === day,
      ),
      b = boot.benchmark.find(
        (r) =>
          r.store_id === selection.store_id &&
          r.dept_id === department &&
          r.day_date === day,
      );
    return {
      day: date(day),
      actual: undefined as number | undefined,
      forecast: f[0].daily_forecast,
      benchmark: b?.predicted_transaction_count_proxy,
      range: [
        f.reduce((s, r) => s + r.demand_low, 0),
        f.reduce((s, r) => s + r.demand_high, 0),
      ],
    };
  });
  const forecasts = [...hist, ...future];
  const pending =
    demand / 100 !== selection.demand_factor ||
    availability / 100 !== selection.availability_factor ||
    stress !== selection.uncertainty;
  const sim =
    selection.demand_factor !== 1 ||
    selection.availability_factor !== 1 ||
    selection.uncertainty !== "central";
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brandmark">
            <Activity size={23} />
          </div>
          <div>
            SHIFTWISE<small>WORKFORCE RESILIENCE</small>
          </div>
        </div>
        <div className="navlabel">OPERATIONS WORKSPACE</div>
        <nav>
          {tabs.map((t, i) => (
            <button
              key={t.name}
              onClick={() => setTab(i)}
              className={i === tab ? "active" : ""}
            >
              <t.icon size={18} />
              <span>{t.name}</span>
              {i === tab && <ChevronRight size={14} />}
            </button>
          ))}
        </nav>
        <div className="forge">
          <div className="navlabel">THE FORGE FRAMEWORK</div>
          {[
            "Forecast demand",
            "Optimize staffing",
            "Reallocate resources",
            "Guard service",
            "Evaluate outcomes",
          ].map((t, i) => (
            <div key={t}>
              <span>{"FORGE"[i]}</span>
              {t}
            </div>
          ))}
        </div>
        <div className="sidebar-bottom">
          <ShieldCheck size={18} />
          <div>
            Evidence over intuition<small>Simulated competition data</small>
          </div>
        </div>
      </aside>
      <main>
        <header>
          <div className="breadcrumb">
            WORKFORCE PLANNING <ChevronRight size={12} /> FEB 12 – 18, 2026
          </div>
          <div className="header-right">
            <span className="dot" />{" "}
            {loading ? "Computing" : "Decision engine online"}
            <div className="avatar">SW</div>
          </div>
        </header>
        <div className="page">
          <div className="page-heading">
            <div>
              <div className="eyebrow">
                TEXAS MISA · FALL 2026 CASE COMPETITION
              </div>
              <h1>{tabs[tab].name}</h1>
              <p>{tabs[tab].caption}. Forecast. Optimize. Adapt.</p>
            </div>
            <button className="tour" onClick={advanceTour}>
              <Play size={15} />
              {tour < 0 ? "Start guided demo" : "Next demo scene"}
              <ArrowRight size={15} />
            </button>
          </div>
          {tour >= 0 && (
            <div className="tour-banner">
              <Sparkles size={17} />
              <div>
                <strong>
                  Scene {tour + 1} / 4 ·{" "}
                  {
                    [
                      "Expected conditions",
                      "Promotion and winter-weather pressure",
                      "Illness and crew shortages",
                      "The Last Worker",
                    ][tour]
                  }
                </strong>
                <span>
                  Warehouse 2 · {date(selection.day_date)} ·{" "}
                  {selection.shift_code}. These controls run the actual solver.
                </span>
              </div>
              <button
                onClick={() => setTour(-1)}
                aria-label="Close guided demo"
              >
                ×
              </button>
            </div>
          )}
          <div className="controls">
            <label>
              <Factory size={15} /> Warehouse
              <select
                aria-label="Warehouse"
                value={selection.store_id}
                onChange={(e) => change({ store_id: +e.target.value })}
              >
                <option value={1}>01 · Medium</option>
                <option value={2}>02 · Large</option>
                <option value={4}>04 · Large</option>
              </select>
            </label>
            <label>
              Date
              <select
                aria-label="Planning date"
                value={selection.day_date}
                onChange={(e) => change({ day_date: e.target.value })}
              >
                {boot.dates.map((d) => (
                  <option key={d} value={d}>
                    {date(d)}, 2026
                  </option>
                ))}
              </select>
            </label>
            <label>
              Shift
              <select
                aria-label="Shift"
                value={selection.shift_code}
                onChange={(e) => change({ shift_code: e.target.value })}
              >
                {["OPEN", "MID", "EVE"].map((s) => (
                  <option key={s}>{s}</option>
                ))}
              </select>
            </label>
            <label>
              Department
              <select
                aria-label="Department"
                value={department}
                onChange={(e) => setDepartment(+e.target.value)}
              >
                {Object.entries(departments).map(([id, d]) => (
                  <option key={id} value={id}>
                    {d}
                  </option>
                ))}
              </select>
            </label>
            <div className="scenario-switch" aria-label="Scenario">
              {["BASE", "PEAK", "DISRUPT"].map((s, i) => (
                <button
                  key={s}
                  className={selection.scenario_id === i + 1 ? "selected" : ""}
                  onClick={() => change({ scenario_id: i + 1 })}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
          {error && (
            <div className="error" role="alert">
              {error}
              <button onClick={() => setSelection({ ...selection })}>
                Retry calculation
              </button>
            </div>
          )}
          {sim && (
            <div className="notice">
              <SlidersHorizontal size={16} /> Custom simulation ·{" "}
              {Math.round(selection.demand_factor * 100)}% demand /{" "}
              {Math.round(selection.availability_factor * 100)}% availability /{" "}
              {selection.uncertainty} forecast. Weekly cards and CSV retain
              official scenarios.<button onClick={reset}>Reset</button>
            </div>
          )}
          {loading && (
            <div className="calculating" role="status">
              <LoaderCircle className="spin" size={15} /> Solving qualified
              workforce allocations…
            </div>
          )}
          {decision && (
            <div
              className={loading ? "result updating" : "result"}
              aria-busy={loading}
            >
              {tab === 0 && (
                <>
                  <div className="section-label">
                    OFFICIAL PLANNING WEEK{" "}
                    <span>
                      All warehouses · Service First · {weekly.scenario_code}
                    </span>
                  </div>
                  <div className="kpis">
                    <Kpi
                      label="Projected labor cost"
                      value={money(weekly.cost)}
                      icon={<Users />}
                      note={`${money(weekly.cost - weekly.draft_cost_hypothetical)} vs hypothetical draft`}
                    />
                    <Kpi
                      label="Modeled service attainment"
                      value={pct(weekly.modeled_service)}
                      icon={<Gauge />}
                      note={`${((weekly.modeled_service - weekly.draft_modeled_service) * 100).toFixed(1)} percentage points vs draft`}
                      accent
                    />
                    <Kpi
                      label="Blocks below 95% estimate"
                      value={String(weekly.at_risk_blocks)}
                      icon={<TriangleAlert />}
                      note="Open blocks with unresolved service risk"
                    />
                    <Kpi
                      label="Infeasible draft groups"
                      value={String(weekly.infeasible_draft_groups)}
                      icon={<ShieldCheck />}
                      note="Warehouse / date / shift groups"
                    />
                  </div>
                  <div className="grid two-one">
                    <section className="card">
                      <CardTitle
                        eyebrow="WORKFORCE OUTLOOK"
                        title={`Warehouse ${selection.store_id} · scenario coverage`}
                        side={
                          <span className="tiny">
                            Employee block assignments / day
                          </span>
                        }
                      />
                      <div className="chart">
                        <ResponsiveContainer>
                          <BarChart data={staffChart} barGap={3}>
                            <CartesianGrid vertical={false} stroke="#edf0f1" />
                            <XAxis
                              dataKey="day"
                              tickLine={false}
                              axisLine={false}
                            />
                            <YAxis
                              tickLine={false}
                              axisLine={false}
                              width={45}
                            />
                            <Tooltip />
                            <Legend />
                            <Bar isAnimationActive={false}
                              dataKey="1"
                              name="BASE"
                              fill="#12877c"
                              radius={[3, 3, 0, 0]}
                            />
                            <Bar isAnimationActive={false}
                              dataKey="2"
                              name="PEAK"
                              fill="#8caeae"
                              radius={[3, 3, 0, 0]}
                            />
                            <Bar isAnimationActive={false}
                              dataKey="3"
                              name="DISRUPT"
                              fill="#dcb56c"
                              radius={[3, 3, 0, 0]}
                            />
                          </BarChart>
                        </ResponsiveContainer>
                      </div>
                      <div className="card-foot">
                        Each count is a full-block assignment, not a unique
                        weekly employee.
                      </div>
                    </section>
                    <section className="card decision-card">
                      <span className="eyebrow light">THE DECISION BRIEF</span>
                      <h2>
                        Right worker.
                        <br />
                        Right place.
                        <br />
                        <em>Right now.</em>
                      </h2>
                      <p>{decision.explanation}</p>
                      <button onClick={() => setTab(4)}>
                        Inspect this decision <ArrowRight size={16} />
                      </button>
                    </section>
                  </div>
                  <div className="grid two-one">
                    <section className="card">
                      <CardTitle
                        eyebrow="SELECTED BLOCK"
                        title="Draft → recommended"
                        side={
                          <Badge
                            ok={
                              decision.certificate.independent_verification
                                .valid
                            }
                          >
                            {decision.certificate.independent_verification.valid
                              ? "Workforce verified"
                              : "Minimum conflict"}
                          </Badge>
                        }
                      />
                      <StaffTable decision={decision} />
                    </section>
                    <section className="card">
                      <CardTitle
                        eyebrow="SCENARIO PULSE"
                        title="Pressure changes the plan"
                      />
                      {boot.summary.map((s) => (
                        <button
                          className="scenario-row"
                          key={s.scenario_id}
                          onClick={() => change({ scenario_id: s.scenario_id })}
                        >
                          <div>
                            <strong>{s.scenario_code}</strong>
                            <small>
                              {s.infeasible_draft_groups} infeasible draft
                              groups
                            </small>
                          </div>
                          <div>
                            <strong>{pct(s.modeled_service)}</strong>
                            <small>{money(s.cost)}</small>
                          </div>
                          <ChevronRight size={15} />
                        </button>
                      ))}
                    </section>
                  </div>
                </>
              )}
              {tab === 1 && (
                <>
                  <div className="kpis three">
                    <Kpi
                      label="Selected forecast method"
                      value={boot.metrics.forecast.selected.replaceAll(
                        "_",
                        " ",
                      )}
                      icon={<BarChart3 />}
                      note="Selected on two past-only weekly-origin folds"
                    />
                    <Kpi
                      label="Macro backtest WAPE"
                      value={pct(
                        boot.metrics.forecast.wape[
                          boot.metrics.forecast.selected
                        ],
                      )}
                      icon={<CheckCheck />}
                      note="126 held-out daily records per method"
                      accent
                    />
                    <Kpi
                      label="Held-out service Brier score"
                      value={sm.test.brier.toFixed(4)}
                      icon={<Gauge />}
                      note={`${departments[department]} · ${sm.test.n} test blocks · lower is better`}
                    />
                  </div>
                  <section className="card">
                    <CardTitle
                      eyebrow="DEPARTMENT-SPECIFIC WORKLOAD UNITS"
                      title={`${departments[department]} · warehouse ${selection.store_id}`}
                      side={
                        <span className="tiny">
                          History → BASE forecast · stress envelope
                        </span>
                      }
                    />
                    <div className="chart tall">
                      <ResponsiveContainer>
                        <AreaChart data={forecasts}>
                          <CartesianGrid vertical={false} stroke="#edf0f1" />
                          <XAxis dataKey="day" interval={3} tickLine={false} />
                          <YAxis tickLine={false} />
                          <Tooltip />
                          <Legend />
                          <Area isAnimationActive={false}
                            type="linear"
                            dataKey="range"
                            name="Stress envelope"
                            stroke="none"
                            fill="#dceee9"
                            connectNulls={false}
                          />
                          <Area isAnimationActive={false}
                            type="linear"
                            dataKey="actual"
                            name="Simulated historical actual"
                            stroke="#142f39"
                            fill="none"
                            strokeWidth={2}
                          />
                          <Area isAnimationActive={false}
                            type="linear"
                            dataKey="forecast"
                            name="Selected BASE forecast"
                            stroke="#12877c"
                            fill="none"
                            strokeWidth={2}
                          />
                          <Area isAnimationActive={false}
                            type="linear"
                            dataKey="benchmark"
                            name="Supplied benchmark"
                            stroke="#d19d43"
                            fill="none"
                            strokeDasharray="4 4"
                          />
                        </AreaChart>
                      </ResponsiveContainer>
                    </div>
                    <div className="card-foot">
                      Bands use held-out residuals plus a documented holiday
                      stress allowance. They are not confidence intervals.
                      Workload units differ by department.
                    </div>
                  </section>
                  <div className="grid equal">
                    <section className="card">
                      <CardTitle
                        eyebrow="PAST-ONLY FORECAST EVALUATION"
                        title="Simple models earn their place"
                      />
                      <table>
                        <thead>
                          <tr>
                            <th>Method</th>
                            <th>Macro WAPE</th>
                            <th>Local WAPE</th>
                          </tr>
                        </thead>
                        <tbody>
                          {Object.entries(boot.metrics.forecast.wape)
                            .sort((a, b) => a[1] - b[1])
                            .map(([m, w]) => (
                              <tr key={m}>
                                <td>
                                  {m.replaceAll("_", " ")}{" "}
                                  {m === boot.metrics.forecast.selected && (
                                    <Check size={13} />
                                  )}
                                </td>
                                <td>{pct(w)}</td>
                                <td>
                                  {pct(
                                    boot.forecast_evaluation.find(
                                      (r) =>
                                        r.method === m &&
                                        r.store_id === selection.store_id &&
                                        r.dept_id === department,
                                    )?.wape,
                                  )}
                                </td>
                              </tr>
                            ))}
                        </tbody>
                      </table>
                      <p className="small-copy">
                        {boot.metrics.forecast.benchmark_note} Model selection
                        scores are not an additional untouched test set. One
                        historical holiday is insufficient to validate a new
                        holiday effect; central forecasts retain neutral
                        adjustments.
                      </p>
                    </section>
                    <section className="card">
                      <CardTitle
                        eyebrow="SERVICE MODEL VALIDATION"
                        title={`${departments[department]} · ${sm.model}`}
                      />
                      <div className="chart">
                        <ResponsiveContainer>
                          <LineChart data={sm.test.calibration}>
                            <CartesianGrid vertical={false} stroke="#edf0f1" />
                            <XAxis
                              dataKey="predicted"
                              type="number"
                              domain={[0, 1]}
                              tickFormatter={(v) => pct(v)}
                            />
                            <YAxis
                              domain={[0, 1]}
                              tickFormatter={(v) => pct(v)}
                            />
                            <Tooltip />
                            <Line isAnimationActive={false}
                              dataKey="observed"
                              name="Observed test attainment"
                              stroke="#12877c"
                              strokeWidth={2}
                            />
                          </LineChart>
                        </ResponsiveContainer>
                      </div>
                      <div className="inline-stats">
                        <span>
                          AUC{" "}
                          <strong>
                            {sm.test.auc?.toFixed(3) ?? "Undefined"}
                          </strong>
                        </span>
                        <span>
                          Calibration ECE{" "}
                          <strong>{sm.test.ece.toFixed(3)}</strong>
                        </span>
                        <span>
                          Historical attainment{" "}
                          <strong>{pct(sm.historical_attainment)}</strong>
                        </span>
                      </div>
                      <p className="small-copy">
                        Selection: Jan 22–28. Held-out test: Jan 29–Feb 11.
                        Final fit: {sm.final_fit_rows} open blocks.
                        Observational associations do not establish causation.
                      </p>
                    </section>
                  </div>
                </>
              )}
              {tab === 2 && (
                <>
                  <div className="mode-bar">
                    <div>
                      <span className="eyebrow">OPERATING PRIORITY</span>
                      <p>
                        Trade modeled service against executable labor cost.
                      </p>
                    </div>
                    <div className="segmented">
                      {boot.modes.map((m) => (
                        <button
                          key={m}
                          onClick={() => change({ mode: m })}
                          className={m === selection.mode ? "chosen" : ""}
                        >
                          {m}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="kpis three">
                    <Kpi
                      label="Selected department · staffing"
                      value={`${a?.draft_employees} → ${a?.employees}`}
                      icon={<Users />}
                      note={`${departments[department]} · ${date(selection.day_date)} · ${selection.shift_code}`}
                    />
                    <Kpi
                      label="Modeled target attainment"
                      value={pct(a?.probability)}
                      icon={<Gauge />}
                      note={`Demand stress range: ${pct(a?.probability_stress_low)} – ${pct(a?.probability_stress_high)}`}
                      accent
                    />
                    <Kpi
                      label="Selected group · labor cost"
                      value={money(decision.plan.cost)}
                      icon={<Factory />}
                      note={`${money(decision.draft.cost)} hypothetical draft`}
                    />
                  </div>
                  <section className="card">
                    <CardTitle
                      eyebrow="JOINT INTEGER WORKFORCE OPTIMIZATION"
                      title="One qualified workforce. No double counting."
                      side={
                        <Badge ok={decision.plan.solver_status === "OPTIMAL"}>
                          {decision.plan.solver_status} · CP-SAT
                        </Badge>
                      }
                    />
                    <StaffTable decision={decision} />
                    <div className="card-foot">
                      Regular staff first → unused qualified partner flex →
                      overtime. Pharmacy uses only its own qualified pool.
                    </div>
                  </section>
                  <div className="grid equal">
                    <section className="card">
                      <CardTitle
                        eyebrow="ALLOCATION MIX"
                        title="Where capacity comes from"
                      />
                      <div className="chart">
                        <ResponsiveContainer>
                          <BarChart
                            data={decision.plan.allocations}
                            layout="vertical"
                          >
                            <CartesianGrid
                              horizontal={false}
                              stroke="#edf0f1"
                            />
                            <XAxis type="number" />
                            <YAxis
                              dataKey="department"
                              type="category"
                              width={110}
                            />
                            <Tooltip />
                            <Legend />
                            <Bar isAnimationActive={false}
                              dataKey="regular"
                              name="Local regular"
                              stackId="a"
                              fill="#12877c"
                            />
                            <Bar isAnimationActive={false}
                              dataKey="flex"
                              name="Borrowed flex"
                              stackId="a"
                              fill="#74bbb0"
                            />
                            <Bar isAnimationActive={false}
                              dataKey="overtime"
                              name="Overtime"
                              stackId="a"
                              fill="#dcb56c"
                            />
                          </BarChart>
                        </ResponsiveContainer>
                      </div>
                    </section>
                    <section className="card">
                      <CardTitle
                        eyebrow="EXPLAIN MY DECISION"
                        title="Traceable, computed reasoning"
                      />
                      <p className="explanation">{decision.explanation}</p>
                      {!decision.draft.valid && (
                        <div className="warning-box">
                          <TriangleAlert size={18} />
                          <div>
                            <strong>Draft is non-executable</strong>
                            <p>
                              Its cost and service are hypothetical.{" "}
                              {decision.draft.errors.join(" ")}
                            </p>
                          </div>
                        </div>
                      )}
                      <p className="small-copy">
                        Service First retains maximum quantized service.
                        Balanced allows a 2-point mean loss; Budget Conscious
                        allows 6 points. Cost is minimized within that limit,
                        then service breaks cost ties.
                      </p>
                    </section>
                  </div>
                </>
              )}
              {tab === 3 && (
                <>
                  <div className="grid lab">
                    <section className="card">
                      <CardTitle
                        eyebrow="SCENARIO INPUTS"
                        title="Change conditions. Recalculate."
                      />
                      <p className="small-copy">
                        Adjust this warehouse/date/shift across all three
                        departments. Official source availability is the
                        ceiling; this control cannot invent additional
                        employees.
                      </p>
                      <label className="range-label">
                        Demand multiplier{" "}
                        <strong>{demand}% of official scenario</strong>
                        <input
                          aria-label="Demand multiplier"
                          type="range"
                          min={70}
                          max={150}
                          step={5}
                          value={demand}
                          onChange={(e) => setDemand(+e.target.value)}
                        />
                        <span>
                          <small>70%</small>
                          <small>150%</small>
                        </span>
                      </label>
                      <label className="range-label">
                        Available workforce{" "}
                        <strong>{availability}% of official pool</strong>
                        <input
                          aria-label="Available workforce"
                          type="range"
                          min={0}
                          max={100}
                          step={5}
                          value={availability}
                          onChange={(e) => setAvailability(+e.target.value)}
                        />
                        <span>
                          <small>0%</small>
                          <small>100%</small>
                        </span>
                      </label>
                      <label className="field">
                        Forecast sensitivity
                        <select
                          aria-label="Forecast sensitivity"
                          value={stress}
                          onChange={(e) =>
                            setStress(
                              e.target.value as Selection["uncertainty"],
                            )
                          }
                        >
                          <option value="central">Central forecast</option>
                          <option value="lower">Lower stress envelope</option>
                          <option value="upper">Upper stress envelope</option>
                        </select>
                      </label>
                      <button
                        className="primary full"
                        disabled={loading}
                        onClick={() =>
                          change({
                            demand_factor: demand / 100,
                            availability_factor: availability / 100,
                            uncertainty: stress,
                          })
                        }
                      >
                        <RefreshCw size={16} /> Recalculate{" "}
                        {pending && <span className="pending-dot" />}
                      </button>
                      <button className="text-button" onClick={reset}>
                        Restore official assumptions
                      </button>
                    </section>
                    <section className="card">
                      <CardTitle
                        eyebrow="LIVE SIMULATION RESULT"
                        title="Protect service within real limits"
                        side={
                          <Badge
                            ok={
                              decision.certificate.independent_verification
                                .valid
                            }
                          >
                            {decision.certificate.status}
                          </Badge>
                        }
                      />
                      <StaffTable decision={decision} />
                      <div className="explanation-box">
                        <Zap size={20} />
                        <p>{decision.explanation}</p>
                      </div>
                      <div className="section-label">
                        RECENT COMPUTED DECISIONS
                      </div>
                      <ol className="decision-log">
                        {log.map((x, i) => (
                          <li key={i}>{x}</li>
                        ))}
                      </ol>
                    </section>
                  </div>
                </>
              )}
              {tab === 4 && (
                <>
                  <div className="grid equal">
                    <section className="card last-worker">
                      <CardTitle
                        eyebrow="SIGNATURE DECISION"
                        title="The Last Worker"
                        side={<GitBranch size={24} />}
                      />
                      <p className="lead">
                        Where does one more qualified worker create the greatest
                        net value?
                      </p>
                      {decision.last_worker.recommendation ? (
                        <>
                          <div className="worker-route">
                            <div>
                              <small>
                                {decision.last_worker.recommendation.donor
                                  ? "LENDING DEPARTMENT"
                                  : "SOURCE"}
                              </small>
                              <strong>
                                {decision.last_worker.recommendation.donor
                                  ? departments[
                                      decision.last_worker.recommendation.donor
                                    ]
                                  : "Unused eligible capacity"}
                              </strong>
                            </div>
                            <ArrowRight />
                            <div>
                              <small>ASSIGN TO</small>
                              <strong>
                                {
                                  departments[
                                    decision.last_worker.recommendation
                                      .recipient
                                  ]
                                }
                              </strong>
                            </div>
                          </div>
                          <div className="inline-stats">
                            <span>
                              Recipient gain{" "}
                              <strong>
                                {(
                                  decision.last_worker.recommendation
                                    .recipient_gain * 100
                                ).toFixed(2)}{" "}
                                pp
                              </strong>
                            </span>
                            <span>
                              Lender effect{" "}
                              <strong>
                                {(
                                  decision.last_worker.recommendation
                                    .donor_effect * 100
                                ).toFixed(2)}{" "}
                                pp
                              </strong>
                            </span>
                            <span>
                              Incremental cost{" "}
                              <strong>
                                {money(
                                  decision.last_worker.recommendation
                                    .incremental_cost,
                                )}
                              </strong>
                            </span>
                          </div>
                        </>
                      ) : (
                        <div className="no-move">
                          <ShieldCheck size={28} />
                          <strong>Keep the current allocation</strong>
                        </div>
                      )}
                      <p className="small-copy">
                        {decision.last_worker.reason} Every option below is
                        checked against qualified pools, closures, and minimums.
                      </p>
                      <div className="scroll">
                        <table>
                          <thead>
                            <tr>
                              <th>Recipient</th>
                              <th>Source</th>
                              <th>Net target gain*</th>
                              <th>Δ cost</th>
                            </tr>
                          </thead>
                          <tbody>
                            {decision.last_worker.alternatives.map((o, i) => (
                              <tr key={i}>
                                <td>{departments[o.recipient]}</td>
                                <td>
                                  {o.donor
                                    ? departments[o.donor]
                                    : "Unused pool"}
                                </td>
                                <td>
                                  {o.net_expected_targets_gain.toFixed(4)}
                                </td>
                                <td>{money(o.incremental_cost)}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      <p className="tiny">
                        *Change in expected count of departments meeting their
                        target, including the lender's loss. Not a causal
                        estimate.
                      </p>
                    </section>
                    <section className="card">
                      <CardTitle
                        eyebrow="INDEPENDENT WORKFORCE CHECK"
                        title="Feasibility Certificate"
                        side={<ShieldCheck className="teal" size={26} />}
                      />
                      <Badge
                        ok={decision.certificate.independent_verification.valid}
                      >
                        {decision.certificate.independent_verification.valid
                          ? "Feasible staffing"
                          : "Minimum staffing conflict"}
                      </Badge>
                      <p className="small-copy">
                        {decision.certificate.qualification}
                      </p>
                      {decision.certificate.constraints.map((c) => (
                        <div className="constraint" key={c.dept_id}>
                          <div>
                            <strong>{departments[c.dept_id]}</strong>
                            <span>{pct(c.probability)} modeled service</span>
                          </div>
                          <p>
                            {c.active.join(" · ") ||
                              "Capacity remains available."}
                          </p>
                          <small>
                            Standalone max: {c.max_employees} workers ·{" "}
                            {pct(c.standalone_max_probability)} service
                          </small>
                        </div>
                      ))}
                      <p className="small-copy">
                        Maximum joint modeled service:{" "}
                        <strong>
                          {pct(decision.certificate.maximum_joint_service)}
                        </strong>
                        . {decision.certificate.interpretation}
                      </p>
                      <details>
                        <summary>Operational responses</summary>
                        <ul>
                          {decision.certificate.actions.map((x) => (
                            <li key={x}>{x}</li>
                          ))}
                        </ul>
                      </details>
                    </section>
                  </div>
                  <div className="grid equal">
                    <section className="card">
                      <CardTitle
                        eyebrow="FEASIBLE NONDOMINATED ALTERNATIVES"
                        title="Cost–service frontier"
                      />
                      <div className="chart">
                        <ResponsiveContainer>
                          <LineChart
                            data={decision.frontier.map((p) => ({
                              cost: Math.round(p.cost),
                              service: +(p.service * 100).toFixed(3),
                            }))}
                          >
                            <CartesianGrid vertical={false} stroke="#edf0f1" />
                            <XAxis
                              dataKey="cost"
                              type="number"
                              domain={["dataMin", "dataMax"]}
                              tickFormatter={(v) => money(v)}
                            />
                            <YAxis
                              dataKey="service"
                              domain={["auto", "auto"]}
                              tickFormatter={(v) => `${v}%`}
                            />
                            <Tooltip
                              formatter={(v, n) =>
                                n === "service" ? `${v}%` : money(Number(v))
                              }
                            />
                            <Line isAnimationActive={false}
                              dataKey="service"
                              name="service"
                              stroke="#12877c"
                              strokeWidth={2}
                              dot={{ r: 5 }}
                            />
                          </LineChart>
                        </ResponsiveContainer>
                      </div>
                      <p className="small-copy">
                        Selected group only. Choose an alternative below to
                        inspect its allocation. Nondominated among eight solved
                        service tolerances, not an enumeration of the entire
                        frontier. Change forecast sensitivity in Scenario Lab to
                        recompute.
                      </p>
                      <div className="frontier-options">
                        {decision.frontier.map((p, i) => (
                          <button
                            key={i}
                            className={frontierIndex === i ? "chosen" : ""}
                            onClick={() => setFrontierIndex(i)}
                            aria-label={`Inspect frontier alternative ${i + 1}`}
                          >
                            {money(p.cost)} · {pct(p.service)}
                          </button>
                        ))}
                      </div>
                      <div className="frontier-preview">
                        {decision.frontier[frontierIndex]?.allocations.map(
                          (a) => (
                            <span key={a.dept_id}>
                              {a.department}
                              <strong>{a.employees} workers</strong>
                              <small>
                                {a.regular} regular · {a.flex} flex ·{" "}
                                {a.overtime} OT
                              </small>
                            </span>
                          ),
                        )}
                      </div>
                    </section>
                    <section className="card export-card">
                      <span className="eyebrow">COMPETITION-READY OUTPUT</span>
                      <h2>
                        A plan you can
                        <br />
                        put to work.
                      </h2>
                      <p>
                        All 567 official scenario rows. Exact template columns
                        and order. Integer employees, closures, minimums, pool
                        conservation and costs independently checked before
                        download.
                      </p>
                      <Badge ok={boot.validation.valid}>
                        {boot.validation.rows} rows ·{" "}
                        {boot.validation.valid
                          ? "validated"
                          : "validation failed"}
                      </Badge>
                      <label className="field">
                        Team ID
                        <input
                          aria-label="Team ID"
                          value={team}
                          maxLength={64}
                          onChange={(e) => setTeam(e.target.value)}
                        />
                      </label>
                      <button
                        className="primary full"
                        disabled={!boot.validation.valid}
                        onClick={download}
                      >
                        <ArrowDownToLine size={17} /> Download staffing
                        submission
                      </button>
                      {exportError && (
                        <p className="error" role="alert">
                          {exportError}
                        </p>
                      )}
                      <small>
                        Export uses Service First and official BASE / PEAK /
                        DISRUPT assumptions. Custom simulations and priority
                        changes do not alter this file.
                      </small>
                    </section>
                  </div>
                  <details className="card">
                    <summary>
                      <CircleHelp size={17} /> Assumptions & evidence
                    </summary>
                    <p>
                      All data is simulated for the student competition, not
                      actual Costco staffing, wages or service. Aggregate
                      availability reflects weekly limits; individual shifts,
                      licenses and hours cannot be audited without person-level
                      records. Front End and Merchandising share only unused
                      qualified partner regular capacity. Department shift
                      labels are the official sharing grain, even when their
                      wall-clock times differ.
                    </p>
                    <p>
                      Forecast history is six weeks. Holiday effects have
                      limited support. Stress envelopes are sensitivity ranges,
                      not confidence intervals. The model predicts target
                      attainment, not validated wait-time minutes. Equal-weight
                      open-block probabilities drive the objective, quantized to
                      0.0001. See repository artifacts and methodology for
                      complete evidence.
                    </p>
                  </details>
                </>
              )}
            </div>
          )}
          <footer>
            <span>
              <ShieldCheck size={13} /> SIMULATED CASE DATA · MODEL ESTIMATES,
              NOT GUARANTEES
            </span>
            <span>
              SHIFTWISE <span className="footer-line" /> Powered by FORGE
            </span>
          </footer>
        </div>
      </main>
    </div>
  );
}
function Kpi({
  label,
  value,
  note,
  icon,
  accent = false,
}: {
  label: string;
  value: string;
  note: string;
  icon: React.ReactNode;
  accent?: boolean;
}) {
  return (
    <div className={`kpi ${accent ? "accent" : ""}`}>
      <div className="kpi-top">
        <span>{label}</span>
        <span className="kpi-icon">{icon}</span>
      </div>
      <strong>{value}</strong>
      <small>{note}</small>
    </div>
  );
}
function CardTitle({
  eyebrow,
  title,
  side,
}: {
  eyebrow: string;
  title: string;
  side?: React.ReactNode;
}) {
  return (
    <div className="card-title">
      <div>
        <span className="eyebrow">{eyebrow}</span>
        <h3>{title}</h3>
      </div>
      {side}
    </div>
  );
}
function StaffTable({ decision }: { decision: Decision }) {
  return (
    <div className="scroll">
      <table className="staff-table">
        <thead>
          <tr>
            <th>Department</th>
            <th>Draft</th>
            <th>Plan</th>
            <th>Regular</th>
            <th>Flex</th>
            <th>OT</th>
            <th>Service estimate</th>
            <th>Cost</th>
          </tr>
        </thead>
        <tbody>
          {decision.plan.allocations.map((a: Allocation) => (
            <tr key={a.dept_id}>
              <td>
                <span className={`dept-dot d${a.dept_id}`} />
                <strong>{a.department}</strong>
                <small>
                  {a.is_open
                    ? `Min ${a.minimum} · ${a.demand.toFixed(1)} workload units`
                    : "Closed block"}
                </small>
              </td>
              <td className="muted">{a.draft_employees}</td>
              <td>
                <strong className="plan-number">{a.employees}</strong>
              </td>
              <td>{a.regular}</td>
              <td>{a.flex}</td>
              <td>{a.overtime}</td>
              <td>
                <span
                  className={`service-pill ${a.probability == null ? "neutral" : a.probability >= 0.95 ? "good" : "warn"}`}
                >
                  {pct(a.probability)}
                </span>
              </td>
              <td>{money(a.cost)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
