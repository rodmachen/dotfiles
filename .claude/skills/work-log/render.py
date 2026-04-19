#!/usr/bin/env python3
"""Render work-log _current.md in v2 format."""
import json
import sys
from pathlib import Path
from datetime import datetime
from collections import defaultdict

ICLOUD_ROOT = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/folio/markdown-notes/work-log"
REPOS_DIR = ICLOUD_ROOT / "repos"

def read_repo_purpose(repo_name):
    """Return the first content line of ## Purpose from the repo state file, or ''."""
    state_file = REPOS_DIR / f"{repo_name}.md"
    if not state_file.exists():
        return ''

    content = state_file.read_text(encoding='utf-8')

    if "## Purpose\n" not in content:
        return ''

    purpose_start = content.find("## Purpose\n") + len("## Purpose\n")
    purpose_end = content.find("\n## ", purpose_start)
    if purpose_end == -1:
        purpose_end = len(content)
    block = content[purpose_start:purpose_end].strip()
    lines = block.split('\n')
    return lines[0] if lines else ''


HYGIENE_LEGEND = (
    "_(Hygiene = drift between git reality and plan/state metadata. "
    "Examples: (a) PR merged for a plan step but step not marked ✅; "
    "(b) user note references a plan that has since moved status; "
    "(c) state file references a plan file that no longer exists on disk; "
    "(d) plan complete but not auto-archived.)_"
)


def render_top_picks(repos_data):
    """Top picks as numbered task list with checkboxes."""
    picks = []

    for repo in repos_data:
        for plan in repo.get('plans', []):
            if plan['status'] == 'in-progress':
                remaining = plan['total_steps'] - plan['completed_steps']
                score = 7 if remaining <= 2 else 2
                picks.append({
                    'repo': repo['name'],
                    'plan': plan['file'],
                    'next_step': plan['next_step'],
                    'reason': f"{plan['completed_steps']}/{plan['total_steps']} steps done",
                    'score': score
                })

    picks.sort(key=lambda x: x['score'], reverse=True)
    picks = picks[:3]

    result = "## Top picks\n\n"
    if not picks:
        result += "_(none)_\n"
    else:
        for i, pick in enumerate(picks, 1):
            result += f"{i}. [ ] **{pick['repo']}/{pick['plan']}** — next: {pick['next_step']} — why: {pick['reason']}\n"

    return result


def render_by_state(repos_data):
    """Render By state section with all subsections as h3."""
    result = "## By state\n\n"

    # Ready to ship
    result += "### Ready to ship\n"
    ready = [(r['name'], r.get('ahead', 0)) for r in repos_data if r.get('ahead', 0) > 0]
    if not ready:
        result += "_(none)_\n"
    else:
        for repo_name, ahead in sorted(ready):
            commits = "commit" if ahead == 1 else "commits"
            result += f"- **{repo_name}** — {ahead} {commits} ahead of origin\n"

    # In progress
    result += "\n### In progress\n"
    in_progress = []
    for repo in repos_data:
        for plan in repo.get('plans', []):
            if plan['status'] == 'in-progress':
                in_progress.append((repo['name'], plan))
    if not in_progress:
        result += "_(none)_\n"
    else:
        for repo_name, plan in in_progress:
            result += f"- **{repo_name}** — {plan['file']}, {plan['completed_steps']}/{plan['total_steps']} steps, next: {plan['next_step']}\n"

    # Plans ready, not started
    result += "\n### Plans ready, not started\n"
    not_started = []
    for repo in repos_data:
        for plan in repo.get('plans', []):
            if plan['status'] == 'not-started':
                not_started.append((repo['name'], plan))
    if not not_started:
        result += "_(none)_\n"
    else:
        for repo_name, plan in sorted(not_started, key=lambda x: (x[0], x[1]['file'])):
            result += f"- **{repo_name}** — {plan['file']}, {plan['total_steps']} steps\n"

    # Open PRs
    result += "\n### Open PRs\n"
    prs = []
    for repo in repos_data:
        for pr in repo.get('open_prs', []):
            prs.append((repo['name'], pr))
    if not prs:
        result += "_(none)_\n"
    else:
        for repo_name, pr in sorted(prs, key=lambda x: x[0]):
            result += f"- **{repo_name}** — #{pr['number']} {pr['title']}\n"

    # Git status (omit section entirely if nothing qualifies)
    dirty_repos = []
    for repo in repos_data:
        if repo['branch'] not in ['main', 'master'] or repo.get('dirty') or repo.get('ahead', 0) > 0:
            parts = []
            if repo['branch'] not in ['main', 'master']:
                parts.append(f"on `{repo['branch']}`")
            if repo.get('dirty'):
                dirty_count = repo.get('dirty_count', 0)
                parts.append(f"dirty ({dirty_count} files)")
            if repo.get('ahead', 0) > 0:
                parts.append(f"ahead {repo['ahead']}")
            if parts:
                dirty_repos.append((repo['name'], ", ".join(parts)))

    if dirty_repos:
        result += "\n### Git status\n"
        for repo_name, status in sorted(dirty_repos):
            result += f"- **{repo_name}** — {status}\n"

    # Hygiene
    hygiene_items = []
    for repo in repos_data:
        archives = repo.get('archives') or {}
        for skipped in archives.get('skipped', []):
            reason = skipped.get('reason', 'unknown')
            hygiene_items.append(
                f"- **{repo['name']}** — {skipped['file']}: "
                f"complete but not archived ({reason}). Fix manually."
            )

    result += "\n### Hygiene\n"
    if not hygiene_items:
        result += "_(none detected)_\n"
    else:
        result += HYGIENE_LEGEND + "\n"
        for item in hygiene_items:
            result += item + "\n"

    # Pre-plans
    result += "\n### Pre-plans\n"
    drafts = []
    for repo in repos_data:
        for plan in repo.get('plans', []):
            if plan['status'] == 'draft':
                drafts.append((repo['name'], plan))
    if not drafts:
        result += "_(none)_\n"
    else:
        for repo_name, plan in sorted(drafts, key=lambda x: (x[0], x[1]['file'])):
            result += f"- **{repo_name}** — {plan['file']} (no Step headings yet)\n"

    return result


def render_all_tracked_repos(repos_data):
    """Render All tracked repos as a Markdown table."""
    result = "## All tracked repos\n\n"
    result += ("Authoritative index of every unfinished plan. Sorted by repo name (alphabetical). "
               "Within each repo, plans sorted by status: in-progress → not-started → draft, "
               "then alphabetically.\n\n")

    result += "| Repository | Plan | Status | Notes |\n"
    result += "|---|---|---|---|\n"

    status_order = {'in-progress': 0, 'not-started': 1, 'draft': 2}

    # Collect every included repo
    included = {}
    for repo in repos_data:
        active_plans = [p for p in repo.get('plans', [])
                        if p['status'] in ('in-progress', 'not-started', 'draft')]
        has_other = (bool(repo.get('open_prs')) or
                     repo.get('dirty', False) or
                     repo.get('ahead', 0) > 0)
        if active_plans or has_other:
            included[repo['name']] = active_plans

    for repo_name in sorted(included.keys()):
        plans = included[repo_name]
        purpose = read_repo_purpose(repo_name)

        if not plans:
            result += f"| {repo_name} | _(no active plans)_ | — | {purpose} |\n"
            continue

        plans.sort(key=lambda p: (status_order.get(p['status'], 99), p['file']))
        for i, plan in enumerate(plans):
            notes = purpose if i == 0 else ''
            status = plan['status']
            if status == 'in-progress':
                status_str = f"in-progress ({plan['completed_steps']}/{plan['total_steps']} steps, next: {plan['next_step']})"
            elif status == 'not-started':
                status_str = f"not-started ({plan['total_steps']} steps)"
            else:
                status_str = "draft (no steps yet)"
            result += f"| {repo_name} | {plan['file']} | {status_str} | {notes} |\n"

    return result


def main():
    if len(sys.argv) > 1:
        repos_data = json.loads(Path(sys.argv[1]).read_text())
    else:
        repos_data = json.load(sys.stdin)

    today = datetime.now().strftime("%Y-%m-%d")

    output = f"# Work log — {today}\n\n"
    output += render_top_picks(repos_data)
    output += "\n"
    output += render_by_state(repos_data)
    output += "\n"
    output += render_all_tracked_repos(repos_data)

    print(output)

if __name__ == '__main__':
    main()
