import json
import time
from pathlib import Path


class TaskQueue:
    def __init__(self, queue_dir: Path):
        self.dir = queue_dir
        self.dir.mkdir(parents=True, exist_ok=True)

    def enqueue(self, role: str, skill: str | None,
                model: str, prompt: str) -> str:
        tid = f"{time.time_ns():020d}"
        task = {
            "id": tid,
            "role": role,
            "skill": skill,
            "model": model,
            "prompt": prompt,
            "status": "queued",
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        (self.dir / f"{tid}-{role}.json").write_text(json.dumps(task, indent=2))
        return tid

    def list_all(self) -> list[dict]:
        return [json.loads(f.read_text()) for f in sorted(self.dir.glob("*.json"))]

    def update_status(self, tid: str, status: str) -> None:
        for f in self.dir.glob(f"{tid}-*.json"):
            data = json.loads(f.read_text())
            data["status"] = status
            f.write_text(json.dumps(data, indent=2))
            return

    def dequeue(self, tid: str) -> None:
        for f in self.dir.glob(f"{tid}-*.json"):
            f.unlink()
            return

    def cancel(self, tid: str) -> bool:
        """Remove a queued task. Returns True if cancelled, False if not found or not queued."""
        for f in self.dir.glob(f"{tid}-*.json"):
            data = json.loads(f.read_text())
            if data["status"] != "queued":
                return False
            f.unlink()
            return True
        return False

    def requeue(self, tid: str) -> bool:
        """Reset a failed/done task back to queued. Returns True if requeued."""
        for f in self.dir.glob(f"{tid}-*.json"):
            data = json.loads(f.read_text())
            if data["status"] not in ("failed", "done"):
                return False
            data["status"] = "queued"
            f.write_text(json.dumps(data, indent=2))
            return True
        return False

    def cleanup(self, statuses: list[str] | None = None, keep_last: int = 50) -> int:
        if statuses is None:
            statuses = ["done", "failed"]
        completed = [t for t in self.list_all() if t["status"] in statuses]
        to_remove = completed[:-keep_last] if keep_last > 0 else completed
        for task in to_remove:
            self.dequeue(task["id"])
        return len(to_remove)
