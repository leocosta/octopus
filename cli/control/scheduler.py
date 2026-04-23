import threading
from datetime import datetime
from pathlib import Path
from typing import Callable

try:
    import yaml
    _YAML_AVAILABLE = True
except ImportError:
    _YAML_AVAILABLE = False

DAYS = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}


class CronParser:
    def fires_at(self, when: str, now: datetime, enabled: bool = True) -> bool:
        if not enabled:
            return False
        parts = when.strip().lower().split()
        if parts[0] == "daily":
            h, m = map(int, parts[1].split(":"))
            return now.hour == h and now.minute == m
        if parts[0] in DAYS:
            h, m = map(int, parts[1].split(":"))
            return now.weekday() == DAYS[parts[0]] and now.hour == h and now.minute == m
        return False


class Scheduler(threading.Thread):
    def __init__(self, schedule_path: Path, on_fire: Callable[[dict], None]):
        super().__init__(daemon=True)
        self.path = schedule_path
        self.on_fire = on_fire
        self._stop = threading.Event()
        self._parser = CronParser()

    def run(self) -> None:
        while not self._stop.wait(timeout=30):
            if not self.path.exists() or not _YAML_AVAILABLE:
                continue
            entries = yaml.safe_load(self.path.read_text()) or []
            now = datetime.now().replace(second=0, microsecond=0)
            for entry in entries:
                if self._parser.fires_at(
                    entry.get("when", ""), now, entry.get("enabled", True)
                ):
                    self.on_fire(entry)

    def stop(self) -> None:
        self._stop.set()
