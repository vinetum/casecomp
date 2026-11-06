"""Optional HTTP calculation deadline; never changes a solver objective."""

from contextvars import ContextVar
import time

DEADLINE = ContextVar("shiftwise_calculation_deadline", default=None)


def solver_seconds(maximum=15.0):
    deadline = DEADLINE.get()
    if deadline is None:
        return maximum
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise RuntimeError("Calculation deadline exceeded; no recommendation produced")
    return min(maximum, remaining)
