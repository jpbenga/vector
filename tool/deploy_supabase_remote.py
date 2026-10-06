#!/usr/bin/env python3
"""Deploy an approved main revision on GitHub, with no macOS credential lookup."""
import json
import os
import subprocess
import urllib.error
import urllib.request

PROJECT_REF = "ednvvxxvlawaagjyshkj"
FUNCTIONS = (
    "sync-live-matches", "api-football-sync", "build-match-feed-snapshot",
    "analyze-match-feed-snapshot", "publish-reading-announcements",
    "daily-football-sync", "ops-worker", "sync-match-results", "admin-ops",
)


def api(url, token):
    request = urllib.request.Request(url, headers={
        "Authorization": "Bearer " + token,
        "Accept": "application/json", "User-Agent": "Lector-remote-deploy",
    })
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # Do not echo API response bodies or credential-bearing request headers.
        raise RuntimeError(f"Management request failed (HTTP {error.code})") from None


def validate_environment(env):
    if env.get("GITHUB_ACTIONS") != "true" or env.get("GITHUB_REF") != "refs/heads/main":
        raise ValueError("Run this workflow on GitHub Actions, from main only.")
    if env.get("GITHUB_REPOSITORY") != "jpbenga/vector":
        raise ValueError("Unexpected repository.")
    for name in ("SUPABASE_ACCESS_TOKEN", "GH_TOKEN", "GITHUB_SHA"):
        if not env.get(name):
            raise ValueError(f"Missing {name}; configure the GitHub secret. No keychain lookup is attempted.")
    target = env.get("DEPLOY_FUNCTION")
    if target == "all-football":
        return FUNCTIONS
    if target not in FUNCTIONS:
        raise ValueError("Select an existing football function.")
    return (target,)


def require_successful_ci(runs, sha):
    if not any(
        run.get("path") == ".github/workflows/ci.yml"
        and run.get("head_sha") == sha
        and run.get("head_branch") == "main"
        and run.get("event") == "push"
        and run.get("conclusion") == "success"
        for run in runs
    ):
        raise ValueError("CI must have passed for this exact main commit before deployment.")


def main():
    env = os.environ
    functions = validate_environment(env)
    sha = env["GITHUB_SHA"]
    runs = api(
        "https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?"
        f"head_sha={sha}&per_page=100", env["GH_TOKEN"],
    )
    require_successful_ci(runs.get("workflow_runs", []), sha)
    print(f"Deploying {len(functions)} football function(s) from {sha}", flush=True)
    for function in functions:
        # These football endpoints enforce identity or the server sync secret
        # in their handler. Preserve their existing deployment configuration.
        subprocess.run([
            "supabase", "functions", "deploy", function,
            "--project-ref", PROJECT_REF, "--use-api", "--no-verify-jwt",
        ], check=True)
    remote = api(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/functions",
        env["SUPABASE_ACCESS_TOKEN"],
    )
    by_slug = {item.get("slug"): item for item in remote}
    for function in functions:
        item = by_slug.get(function, {})
        if item.get("status") != "ACTIVE" or item.get("verify_jwt") is not False:
            raise RuntimeError(f"Remote verification failed for {function}")
        print(json.dumps({"function": function, "version": item.get("version"),
                          "status": item.get("status"), "verify_jwt": False}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
