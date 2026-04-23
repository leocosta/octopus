import sys
sys.path.insert(0, ".")
from cli.control.scheduler import CronParser
from datetime import datetime


def test_daily():
    cp = CronParser()
    assert cp.fires_at("daily 09:00", datetime(2026, 4, 22, 8, 59, 0)) is False
    assert cp.fires_at("daily 09:00", datetime(2026, 4, 22, 9, 0, 0)) is True


def test_weekly():
    cp = CronParser()
    # 2026-04-20 is a Monday
    assert cp.fires_at("Mon 08:00", datetime(2026, 4, 20, 8, 0)) is True
    assert cp.fires_at("Mon 08:00", datetime(2026, 4, 21, 8, 0)) is False


def test_disabled():
    cp = CronParser()
    assert cp.fires_at("daily 09:00", datetime(2026, 4, 22, 9, 0), enabled=False) is False
