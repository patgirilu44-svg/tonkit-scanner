#!/usr/bin/env python3
"""
ci-review.py
AI code review script called by GitHub Actions pipeline.
Sends git diff to Claude API, writes pass/fail result to GITHUB_OUTPUT.
"""

import json
import os
import sys
import urllib.request
import urllib.error

REVIEW_RULES = (
    "Review this TypeScript/JavaScript diff for these issues:\n"
    "1. Hardcoded secrets, API keys, or passwords\n"
    "2. Missing input validation on API routes\n"
    "3. Contract source code being stored in database (FORBIDDEN)\n"
    "4. The word 'audit' in user-facing copy (FORBIDDEN - use 'scan' or 'analysis')\n"
    "5. Missing maxDuration export on /api/scan route\n"
    "6. Claude API model string not equal to claude-sonnet-4-6\n"
    "7. SQL injection or unsafe Supabase queries\n"
    "8. Unhandled promise rejections in API route handlers\n"
    "9. TypeScript 'any' types used without justification comment\n"
)

RESPONSE_FORMAT = (
    'Respond ONLY with valid JSON, no markdown, no extra text:\n'
    '{"passed": true, "issues": [], "summary": "No issues found."}\n\n'
    'When issues exist:\n'
    '{"passed": false, "issues": [{"severity": "HIGH", "file": "path/to/file.ts", '
    '"description": "what is wrong", "fix": "how to fix it"}], "summary": "brief summary"}'
)


def write_output(passed: bool, issues: list, github_output: str) -> None:
    issues_json = json.dumps(issues)
    with open(github_output, "a") as f:
        f.write("passed=" + ("true" if passed else "false") + "\n")
        f.write("issues<<ISSUES_EOF\n")
        f.write(issues_json + "\n")
        f.write("ISSUES_EOF\n")


def call_claude(prompt: str, api_key: str) -> dict:
    payload = json.dumps({
        "model": "claude-sonnet-4-6",
        "max_tokens": 1000,
        "messages": [{"role": "user", "content": prompt}]
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01"
        }
    )

    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read().decode("utf-8"))
        return body


def parse_response(text: str) -> dict:
    text = text.strip()
    # Strip markdown code fences if present
    if text.startswith("```"):
        lines = text.split("\n")
        start = 1
        end = len(lines)
        if lines[-1].strip() in ("```", "```json"):
            end = -1
        text = "\n".join(lines[start:end]).strip()
    return json.loads(text)


def main() -> None:
    diff = os.environ.get("DIFF", "").strip()
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    github_output = os.environ.get("GITHUB_OUTPUT", "/dev/null")

    if not diff:
        print("No TypeScript/JavaScript diff to review — skipping.")
        write_output(True, [], github_output)
        sys.exit(0)

    if not api_key:
        print("ERROR: ANTHROPIC_API_KEY not set")
        error = [{"severity": "HIGH", "file": "ci", "description": "ANTHROPIC_API_KEY missing", "fix": "Set secret in GitHub repo settings"}]
        write_output(False, error, github_output)
        sys.exit(1)

    prompt = (
        "You are a code reviewer for TonKit Scanner, a TON blockchain smart contract scanner.\n\n"
        + REVIEW_RULES
        + "\n"
        + RESPONSE_FORMAT
        + "\n\nDIFF TO REVIEW:\n"
        + diff
    )

    try:
        body = call_claude(prompt, api_key)
        text = body["content"][0]["text"]
        result = parse_response(text)

        passed = bool(result.get("passed", False))
        issues = result.get("issues", [])
        summary = result.get("summary", "")

        print("Review result:", "PASSED" if passed else "FAILED")
        print("Issues found:", len(issues))
        print("Summary:", summary)

        if not passed and issues:
            with open("/tmp/review_issues.json", "w") as f:
                json.dump(issues, f, indent=2)
            print("Issues written to /tmp/review_issues.json")
            for issue in issues:
                print(f"  [{issue.get('severity')}] {issue.get('file')}: {issue.get('description')}")

        write_output(passed, issues, github_output)

    except (urllib.error.URLError, urllib.error.HTTPError) as e:
        print("API request failed:", str(e))
        error = [{"severity": "HIGH", "file": "ci", "description": "Claude API unreachable: " + str(e)[:200], "fix": "Check ANTHROPIC_API_KEY and network"}]
        with open("/tmp/review_issues.json", "w") as f:
            json.dump(error, f)
        write_output(False, error, github_output)
        sys.exit(1)

    except (json.JSONDecodeError, KeyError, IndexError) as e:
        print("Response parse failed:", str(e))
        error = [{"severity": "HIGH", "file": "ci", "description": "Review parse error: " + str(e)[:200], "fix": "Re-run pipeline"}]
        with open("/tmp/review_issues.json", "w") as f:
            json.dump(error, f)
        write_output(False, error, github_output)
        sys.exit(1)


if __name__ == "__main__":
    main()
