import os

os.environ.setdefault("MPLCONFIGDIR", "/tmp/shiftwise-mpl")
os.environ.setdefault("XDG_CACHE_HOME", "/tmp/shiftwise-cache")
import pytest
from backend.engine import Engine


@pytest.fixture(scope="session")
def engine():
    return Engine()
