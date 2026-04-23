import sys
sys.path.insert(0, ".")
from cli.control.queue import TaskQueue
from pathlib import Path


def test_enqueue_dequeue(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    tid = q.enqueue(role="backend-specialist", skill="security-scan",
                    model="claude-sonnet-4-6", prompt="scan auth/")
    tasks = q.list_all()
    assert len(tasks) == 1 and tasks[0]["id"] == tid
    q.update_status(tid, "running")
    assert q.list_all()[0]["status"] == "running"


def test_concurrent_enqueue(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    ids = {q.enqueue("tech-writer", None, "claude-sonnet-4-6", f"t{i}") for i in range(5)}
    assert len(ids) == 5
