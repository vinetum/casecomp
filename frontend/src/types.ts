export type Mode = "Service First" | "Balanced" | "Budget Conscious";
export interface Selection {
  scenario_id: number;
  store_id: number;
  day_date: string;
  shift_code: string;
  mode: Mode;
  demand_factor: number;
  availability_factor: number;
  uncertainty: "central" | "lower" | "upper";
}
export interface Allocation {
  dept_id: number;
  department: string;
  employees: number;
  regular: number;
  flex: number;
  overtime: number;
  cost: number;
  probability: number | null;
  probability_stress_low: number | null;
  probability_stress_high: number | null;
  is_open: boolean;
  minimum: number;
  minimum_shortfall: number;
  utilization: number | null;
  demand: number;
  demand_low: number;
  demand_high: number;
  available_regular: number;
  flex_cap: number;
  overtime_cap: number;
  draft_employees: number;
  availability_note: string | null;
  scenario_id?: number;
  store_id?: number;
  day_date?: string;
  shift_code?: string;
}
export interface Plan {
  allocations: Allocation[];
  cost: number;
  service: number;
  tolerance: number;
  solver_status: string;
  minimum_staffing_shortfall: number;
}
export interface Alternative {
  recipient: number;
  donor: number | null;
  kind: string;
  net_expected_targets_gain: number;
  incremental_cost: number;
  recipient_gain: number;
  donor_effect: number;
  allocations: Allocation[];
}
export interface Decision {
  selection: Selection;
  plan: Plan;
  draft: {
    valid: boolean;
    errors: string[];
    cost: number;
    allocations: {
      dept_id: number;
      employees: number;
      cost: number;
      probability: number | null;
    }[];
  };
  certificate: {
    status: string;
    minimum_shortfall: number;
    maximum_joint_service: number;
    independent_verification: { valid: boolean; errors: string[] };
    constraints: {
      dept_id: number;
      active: string[];
      max_employees: number;
      standalone_max_probability: number | null;
      probability: number | null;
      minimum_shortfall: number;
      regular_unused: number;
    }[];
    qualification: string;
    interpretation: string;
    actions: string[];
  };
  last_worker: {
    recommendation: Alternative | null;
    alternatives: Alternative[];
    reason: string;
  };
  frontier: Plan[];
  explanation: string;
}
export interface Summary {
  scenario_id: number;
  scenario_code: string;
  cost: number;
  draft_cost_hypothetical: number;
  modeled_service: number;
  draft_modeled_service: number;
  at_risk_blocks: number;
  employees: number;
  overtime: number;
  flex: number;
  infeasible_draft_groups: number;
}
export interface ServiceMetric {
  model: string;
  final_fit_rows: number;
  historical_attainment: number;
  test: {
    n: number;
    brier: number;
    auc: number | null;
    ece: number;
    calibration: {
      lower: number;
      n: number;
      predicted: number;
      observed: number;
    }[];
  };
}
export interface Bootstrap {
  summary: Summary[];
  validation: { valid: boolean; rows: number };
  metrics: {
    forecast: {
      selected: string;
      wape: Record<string, number>;
      origins: string[];
      benchmark_note: string;
    };
    service: Record<string, ServiceMetric>;
  };
  dates: string[];
  modes: Mode[];
  allocations: Allocation[];
  historical: {
    store_id: number;
    dept_id: number;
    day_date: string;
    daily_demand_units: number;
  }[];
  forecasts: {
    store_id: number;
    dept_id: number;
    day_date: string;
    shift_code: string;
    daily_forecast: number;
    demand: number;
    demand_low: number;
    demand_high: number;
    calendar_factor_applied: number;
    calendar_analogue_factor: number;
    calendar_support_days: number;
  }[];
  forecast_evaluation: {
    store_id: number;
    dept_id: number;
    method: string;
    wape: number;
    mae: number;
    n: number;
  }[];
  benchmark: {
    store_id: number;
    dept_id: number;
    day_date: string;
    daily_forecast: number;
    predicted_transaction_count_proxy: number;
  }[];
}
