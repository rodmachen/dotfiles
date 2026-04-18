#!/usr/bin/env python3
"""Render work-log _current.md in v2 format."""
import json
import sys
import subprocess
from pathlib import Path
from datetime import datetime
from collections import defaultdict

ICLOUD_ROOT = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/folio/markdown-notes/work-log"
REPOS_DIR = ICLOUD_ROOT / "repos"

def read_repo_state(repo_name):
    """Extract Purpose section from repo state file if exists."""
    state_file = REPOS_DIR / f"{repo_name}.md"
    if not state_file.exists():
        return {}

    content = state_file.read_text(encoding='utf-8')

    # Extract Purpose section (first non-empty line after ## Purpose)
    if "## Purpose\n" in content:
        purpose_start = content.find("## Purpose\n") + len("## Purpose\n")
        purpose_end = content.find("\n## ", purpose_start)
        if purpose_end == -1:
            purpose_end = len(content)
        purpose_lines = content[purpose_start:purpose_end].strip().split('\n')
        purpose = purpose_lines[0] if purpose_lines[0] else None
        return {'purpose': purpose}

    return {}

def render_top_picks(repos_data):
    """Top picks as numbered task list with checkboxes."""
    picks = []

    # Collect all actionable items with simple scoring
    for repo in repos_data:
        for plan in repo.get('plans', []):
            if plan['status'] == 'in-progress':
                score = 7 if plan['total_steps'] - plan['completed_steps'] <= 2 else 2
                picks.append({
                    'repo': repo['name'],
                    'plan': plan['file'],
                    'next_step': plan['next_step'],
                    'reason': f"{plan['completed_steps']}/{plan['total_steps']} steps done",
                    'score': score
                })

    # Sort by score descending, take top 3
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
    """Render By state section (similar to old format)."""
    result = "## By state\n\n"

    # In progress
    result += "### In progress\n"
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

def render_git_status(repos_data):
    """Render Git status section (new in v2)."""
    result = "## Git status\n\n"

    dirty_repos = []
    for repo in repos_data:
        if repo['branch'] not in ['main', 'master'] or repo['dirty'] or repo['ahead'] > 0:
            status_parts = []
            if repo['branch'] not in ['main', 'master']:
                status_parts.append(f"on `{repo['branch']}`")
            if repo['dirty']:
                status_parts.append("dirty")
            if repo['ahead'] > 0:
                status_parts.append(f"ahead {repo['ahead']}")

            if status_parts:
                dirty_repos.append((repo['name'], ", ".join(status_parts)))

    if not dirty_repos:
        return ""  # Omit section entirely if no repos qualify

    for repo_name, status in sorted(dirty_repos):
        result += f"- **{repo_name}** — {status}\n"

    return result

def render_all_tracked_repos(repos_data):
    """Render All tracked repos with nested structure grouped by repo and status."""
    result = "## All tracked repos\n\n"

    # Group plans by repo and status
    repos_by_name = defaultdict(lambda: {'in-progress': [], 'not-started': [], 'draft': []})

    for repo in repos_data:
        for plan in repo.get('plans', []):
            if plan['status'] in ['in-progress', 'not-started', 'draft']:
                repos_by_name[repo['name']][plan['status']].append(plan)

    # Sort plans within each group alphabetically
    for repo_name in repos_by_name:
        for status in repos_by_name[repo_name]:
            repos_by_name[repo_name][status].sort(key=lambda p: p['file'])

    # Render by repo (sorted alphabetically)
    for repo_name in sorted(repos_by_name.keys()):
        groups = repos_by_name[repo_name]

        # Skip if no plans
        if not any(groups.values()):
            continue

        result += f"### {repo_name}\n"

        # Add Purpose line if exists
        repo_state = read_repo_state(repo_name)
        if repo_state.get('purpose'):
            result += f"> {repo_state['purpose']}\n\n"

        # Render each status group in order: in-progress, not-started, draft
        for status in ['in-progress', 'not-started', 'draft']:
            if not groups[status]:
                continue

            status_label = {
                'in-progress': 'In progress',
                'not-started': 'Not started',
                'draft': 'Draft'
            }[status]

            result += f"**{status_label}**\n"
            for plan in groups[status]:
                if status == 'in-progress':
                    result += f"- {plan['file']} — {plan['completed_steps']}/{plan['total_steps']} steps, next: {plan['next_step']}\n"
                elif status == 'not-started':
                    result += f"- {plan['file']} — {plan['total_steps']} steps\n"
                else:  # draft
                    result += f"- {plan['file']} — no steps yet\n"
            result += "\n"

    return result

def main():
    # Read scan output
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

    git_status = render_git_status(repos_data)
    if git_status:
        output += git_status
        output += "\n"

    output += "### Hygiene\n_(none detected)_\n\n"
    output += render_all_tracked_repos(repos_data)

    print(output)

if __name__ == '__main__':
    main()
