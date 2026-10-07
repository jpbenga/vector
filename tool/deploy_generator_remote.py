"""Install only the AI drafts backend, on GitHub, with no local credential lookup."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.request

PROJECT = "ednvvxxvlawaagjyshkj"
VERSION = "20261008120000"
MIGRATION = Path("supabase/migrations/20261008120000_lector_generator.sql")
MODELS = {"gpt-4.1-mini-2025-04-14", "gpt-4.1-nano-2025-04-14"}


def request(url, token, body=None):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), headers={
        "Authorization": "Bearer " + token, "Accept": "application/json", "Content-Type": "application/json", "User-Agent": "Lector-generator-deploy"})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        # Responses to secret installation may contain secrets: never print them.
        raise RuntimeError(f"Remote request failed (HTTP {error.code})") from None


def validate_environment(env):
    if env.get("GITHUB_ACTIONS") != "true" or env.get("GITHUB_REF") != "refs/heads/codex/multisport-hockey" or env.get("GITHUB_REPOSITORY") != "jpbenga/vector":
        raise ValueError("This generator installation runs on the multisport GitHub branch only.")
    for name in ("SUPABASE_ACCESS_TOKEN", "OPENAI_API_KEY", "GH_TOKEN", "GITHUB_SHA"):
        if not env.get(name):
            raise ValueError(f"Missing repository secret {name}. No keychain fallback.")


def require_ci(runs, sha):
    if not any(r.get("path") == ".github/workflows/ci.yml" and r.get("head_sha") == sha and r.get("head_branch") == "codex/multisport-hockey" and r.get("event") == "push" and r.get("conclusion") == "success" for r in runs):
        raise ValueError("CI must pass for the exact multisport revision before installation.")


def main():
    env = os.environ
    validate_environment(env)
    runs = request(f"https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={env['GITHUB_SHA']}&per_page=100", env["GH_TOKEN"])
    require_ci(runs.get("workflow_runs", []), env["GITHUB_SHA"])
    token = env["SUPABASE_ACCESS_TOKEN"]
    base = f"https://api.supabase.com/v1/projects/{PROJECT}"
    def query(sql, read_only=False):
        return request(base + "/database/query", token, {"query": sql, "read_only": read_only})
    sql = MIGRATION.read_text()
    prior = query(f"select statements from supabase_migrations.schema_migrations where version='{VERSION}'", True)
    if prior:
        if prior[0].get("statements") != [sql]:
            raise ValueError("Installed generator migration differs; create a new migration before changing it.")
    else:
        if "$lector_generator_sql$" in sql:
            raise ValueError("Unexpected SQL delimiter.")
        query("begin;\n" + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{VERSION}','lector_generator',array[$lector_generator_sql${sql}$lector_generator_sql$]);\ncommit;")
    subprocess.run(["deno", "run", "--allow-env=OPENAI_API_KEY,SUPABASE_ACCESS_TOKEN", "--allow-net=api.openai.com,api.supabase.com", "--allow-write=/tmp/lector-generator-model.txt", "tool/benchmark_lector_generator.ts"], check=True)
    model = Path("/tmp/lector-generator-model.txt").read_text().strip()
    if model not in MODELS:
        raise ValueError("No verified test model selected.")
    # Disable before redeploy. Preserve every existing football/hockey secret.
    config = {"OPENAI_API_KEY": env["OPENAI_API_KEY"], "LECTOR_OPENAI_MODEL": model, "LECTOR_GENERATOR_ENABLED": "false", "LECTOR_GENERATOR_USER_DAILY_LIMIT": "5", "LECTOR_GENERATOR_DAILY_LIMIT": "20"}
    request(base + "/secrets", token, [{"name": n, "value": v} for n, v in config.items()])
    subprocess.run(["supabase", "functions", "deploy", "lector-generator", "--project-ref", PROJECT, "--use-api", "--no-verify-jwt"], check=True)
    remote = request(base + "/functions/lector-generator", token)
    if remote.get("status") != "ACTIVE" or remote.get("verify_jwt") is not False:
        raise RuntimeError("Generator function deployment was not verified.")
    # Check anonymous requests fail before switching on paid interpretations.
    req = urllib.request.Request(f"https://{PROJECT}.supabase.co/functions/v1/lector-generator", data=b'{}', headers={"Content-Type":"application/json"})
    try:
        urllib.request.urlopen(req, timeout=30)
        raise RuntimeError("Anonymous generator request was unexpectedly accepted.")
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise RuntimeError("Anonymous protection check failed.") from None
    request(base + "/secrets", token, [{"name":"LECTOR_GENERATOR_ENABLED","value":"true"}])
    print(json.dumps({"function":"lector-generator","active":True,"model":model,"user_daily_limit":5,"global_daily_limit":20,"test_envelope_usd":3,"migration_sha256":hashlib.sha256(sql.encode()).hexdigest()}))


if __name__ == "__main__":
    main()
