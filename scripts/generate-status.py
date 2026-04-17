#!/usr/bin/env python3
# generate-status.py
# Runs on VPS via cron (daily), generates status HTML, copies to Next.js public dir,
# commits and pushes so it deploys with the app.

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

REPO_DIR = Path.home() / "tonkit"
LOG_DIR = REPO_DIR / "logs"
OUTPUT_PATH = REPO_DIR / "public" / "status.html"

def read_jsonl(path):
    if not path.exists():
        return []
    events = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return events

def parse_roadmap():
    roadmap_path = REPO_DIR / "ROADMAP.md"
    if not roadmap_path.exists():
        return []
    
    tasks = []
    current = {}
    
    with open(roadmap_path) as f:
        content = f.read()
    
    blocks = content.split("## TASK:")
    for block in blocks[1:]:
        lines = block.strip().split("\n")
        task_id = lines[0].strip()
        status = "UNKNOWN"
        title = ""
        
        for line in lines:
            if line.startswith("STATUS:"):
                status = line.replace("STATUS:", "").strip()
            if line.startswith("TITLE:"):
                title = line.replace("TITLE:", "").strip()
        
        tasks.append({"id": task_id, "status": status, "title": title})
    
    return tasks

def get_recent_deploys(n=5):
    deploys = read_jsonl(LOG_DIR / "deploys.jsonl")
    return sorted(deploys, key=lambda x: x.get("timestamp",""), reverse=True)[:n]

def get_recent_failures(n=5):
    failures = read_jsonl(LOG_DIR / "failures.jsonl")
    return sorted(failures, key=lambda x: x.get("timestamp",""), reverse=True)[:n]

def get_recent_events(n=10):
    events = read_jsonl(LOG_DIR / "events.jsonl")
    return sorted(events, key=lambda x: x.get("timestamp",""), reverse=True)[:n]

def needs_human(tasks, failures):
    reasons = []
    failed_tasks = [t for t in tasks if t["status"] == "FAILED"]
    if failed_tasks:
        reasons.append(f"{len(failed_tasks)} task(s) marked FAILED in ROADMAP — reset to PENDING or investigate")
    
    max_cycle_failures = [f for f in failures if f.get("type") == "MAX_REVIEW_CYCLES_EXCEEDED"]
    if max_cycle_failures:
        reasons.append(f"Review cycle exceeded {len(max_cycle_failures)} time(s) — AI cannot self-fix, manual code review needed")
    
    fix_agent_failures = [f for f in failures if f.get("type") == "FIX_AGENT_FAILED"]
    if fix_agent_failures:
        reasons.append(f"Fix agent failed {len(fix_agent_failures)} time(s) — SSH/Claude Code connectivity issue")
    
    return reasons

def status_color(status):
    return {
        "DONE": "#22c55e",
        "IN_PROGRESS": "#f59e0b",
        "PENDING": "#6b7280",
        "FAILED": "#ef4444",
    }.get(status, "#6b7280")

def generate_html(tasks, deploys, failures, events):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    human_items = needs_human(tasks, failures)
    
    done = len([t for t in tasks if t["status"] == "DONE"])
    total = len(tasks)
    in_progress = [t for t in tasks if t["status"] == "IN_PROGRESS"]
    failed = [t for t in tasks if t["status"] == "FAILED"]
    
    human_section = ""
    if human_items:
        items_html = "".join(f'<li style="color:#ef4444;margin:6px 0">{item}</li>' for item in human_items)
        human_section = f"""
        <div style="background:#1a0000;border:2px solid #ef4444;border-radius:8px;padding:20px;margin-bottom:24px">
          <h2 style="color:#ef4444;margin:0 0 12px;font-size:16px;text-transform:uppercase;letter-spacing:0.1em">
            ⚠ HUMAN DECISION REQUIRED
          </h2>
          <ul style="margin:0;padding-left:20px">{items_html}</ul>
        </div>"""
    
    task_rows = "".join(f"""
      <tr>
        <td style="padding:10px 12px;font-family:monospace;font-size:13px;color:#94a3b8">{t['id']}</td>
        <td style="padding:10px 12px;font-size:13px;color:#e2e8f0">{t['title']}</td>
        <td style="padding:10px 12px">
          <span style="background:{status_color(t['status'])}22;color:{status_color(t['status'])};
                       padding:3px 10px;border-radius:4px;font-size:12px;font-weight:600;
                       font-family:monospace">{t['status']}</span>
        </td>
      </tr>""" for t in tasks)
    
    deploy_rows = "".join(f"""
      <tr>
        <td style="padding:8px 12px;font-family:monospace;font-size:12px;color:#94a3b8">
          {d.get('timestamp','')[:19]}</td>
        <td style="padding:8px 12px;font-family:monospace;font-size:12px;color:#22c55e">
          {d.get('commit','')}</td>
        <td style="padding:8px 12px;font-size:12px;color:#e2e8f0">
          {d.get('message','')[:80]}</td>
      </tr>""" for d in deploys) or '<tr><td colspan="3" style="padding:12px;color:#6b7280;font-size:13px">No deploys yet</td></tr>'
    
    failure_rows = "".join(f"""
      <tr>
        <td style="padding:8px 12px;font-family:monospace;font-size:12px;color:#94a3b8">
          {f.get('timestamp','')[:19]}</td>
        <td style="padding:8px 12px;font-size:12px;color:#ef4444">
          {f.get('type','')}</td>
        <td style="padding:8px 12px;font-size:12px;color:#e2e8f0">
          {str(f.get('issues', f.get('exit_code', '')))[:80]}</td>
      </tr>""" for f in failures) or '<tr><td colspan="3" style="padding:12px;color:#22c55e;font-size:13px">No failures</td></tr>'
    
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="300">
<title>TonKit Pipeline Status</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: #0a0f1a; color: #e2e8f0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 24px; min-height: 100vh; }}
  h1 {{ font-size: 22px; font-weight: 700; color: #f8fafc; margin-bottom: 4px; }}
  h2 {{ font-size: 14px; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 14px; }}
  .meta {{ font-size: 12px; color: #475569; margin-bottom: 28px; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; margin-bottom: 28px; }}
  .stat {{ background: #111827; border: 1px solid #1e293b; border-radius: 8px; padding: 16px; }}
  .stat-n {{ font-size: 36px; font-weight: 700; line-height: 1; }}
  .stat-l {{ font-size: 12px; color: #64748b; margin-top: 6px; }}
  section {{ background: #111827; border: 1px solid #1e293b; border-radius: 8px; padding: 20px; margin-bottom: 20px; }}
  table {{ width: 100%; border-collapse: collapse; }}
  tr:not(:last-child) td {{ border-bottom: 1px solid #1e293b; }}
  .progress-bar {{ background: #1e293b; border-radius: 4px; height: 8px; margin-top: 8px; }}
  .progress-fill {{ background: #22c55e; border-radius: 4px; height: 8px; width: {int(done/total*100) if total else 0}%; }}
</style>
</head>
<body>
<h1>TonKit Scanner — Pipeline Status</h1>
<p class="meta">Generated {now} · Auto-refreshes every 5 minutes</p>

{human_section}

<div class="grid">
  <div class="stat">
    <div class="stat-n" style="color:#22c55e">{done}</div>
    <div class="stat-l">Tasks done</div>
  </div>
  <div class="stat">
    <div class="stat-n" style="color:#f59e0b">{len(in_progress)}</div>
    <div class="stat-l">In progress</div>
  </div>
  <div class="stat">
    <div class="stat-n" style="color:#ef4444">{len(failed)}</div>
    <div class="stat-l">Failed</div>
  </div>
  <div class="stat">
    <div class="stat-n" style="color:#6b7280">{total - done - len(in_progress) - len(failed)}</div>
    <div class="stat-l">Pending</div>
  </div>
  <div class="stat">
    <div class="stat-n" style="color:#3b82f6">{len(deploys)}</div>
    <div class="stat-l">Recent deploys</div>
  </div>
</div>

<div style="background:#111827;border:1px solid #1e293b;border-radius:8px;padding:20px;margin-bottom:20px">
  <h2>Roadmap progress — {done}/{total}</h2>
  <div class="progress-bar"><div class="progress-fill"></div></div>
</div>

<section>
  <h2>Task Status</h2>
  <table>
    <thead>
      <tr style="border-bottom:2px solid #1e293b">
        <th style="padding:8px 12px;text-align:left;font-size:12px;color:#64748b;font-weight:600">ID</th>
        <th style="padding:8px 12px;text-align:left;font-size:12px;color:#64748b;font-weight:600">Task</th>
        <th style="padding:8px 12px;text-align:left;font-size:12px;color:#64748b;font-weight:600">Status</th>
      </tr>
    </thead>
    <tbody>{task_rows}</tbody>
  </table>
</section>

<section>
  <h2>Recent Deploys</h2>
  <table>
    <tbody>{deploy_rows}</tbody>
  </table>
</section>

<section>
  <h2>Failures Log</h2>
  <table>
    <tbody>{failure_rows}</tbody>
  </table>
</section>

</body>
</html>"""

if __name__ == "__main__":
    tasks = parse_roadmap()
    deploys = get_recent_deploys()
    failures = get_recent_failures()
    events = get_recent_events()
    
    html = generate_html(tasks, deploys, failures, events)
    
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(html)
    
    print(f"Status page written to {OUTPUT_PATH}")
    
    # Commit and push
    os.chdir(REPO_DIR)
    subprocess.run(["git", "add", "public/status.html"], check=False)
    
    result = subprocess.run(
        ["git", "diff", "--cached", "--quiet"],
        capture_output=True
    )
    
    if result.returncode != 0:
        subprocess.run([
            "git", "commit", "-m",
            f"chore: update pipeline status dashboard [skip ci]"
        ], check=False)
        subprocess.run(["git", "push", "origin", "main"], check=False)
        print("Status page committed and pushed.")
    else:
        print("No changes to status page.")
