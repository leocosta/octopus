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


def test_cleanup_removes_done_tasks(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    ids = [q.enqueue("worker", None, "claude-sonnet-4-6", f"t{i}") for i in range(5)]
    for tid in ids:
        q.update_status(tid, "done")
    removed = q.cleanup(keep_last=2)
    assert removed == 3
    assert len(q.list_all()) == 2


def test_cleanup_keeps_queued_and_running(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    q.enqueue("worker", None, "claude-sonnet-4-6", "running-task")
    q.update_status(q.list_all()[0]["id"], "running")
    q.enqueue("worker", None, "claude-sonnet-4-6", "queued-task")
    removed = q.cleanup(keep_last=0)
    assert removed == 0
    assert len(q.list_all()) == 2


def test_cleanup_failed_tasks(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    tid = q.enqueue("worker", None, "claude-sonnet-4-6", "bad-task")
    q.update_status(tid, "failed")
    removed = q.cleanup(keep_last=0)
    assert removed == 1
    assert len(q.list_all()) == 0
