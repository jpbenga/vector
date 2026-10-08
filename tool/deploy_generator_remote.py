"""Install only the AI drafts backend, on GitHub, with no local credential lookup."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request

PROJECT = "ednvvxxvlawaagjyshkj"
VERSION = "20261008120000"
MIGRATION = Path("supabase/migrations/20261008120000_lector_generator.sql")
MODELS = {"gpt-4.1-mini-2025-04-14", "gpt-4.1-nano-2025-04-14", "gpt-6.1-sol", "gpt-6-luna"}


def sql_diagnostic(body):
    """Print only known SQL identifiers; never raw responses, rows or queries."""
    try:
        message = str(json.loads(body).get("message", ""))
    except (ValueError, AttributeError):
        return ""
    match = re.search(r'(?:relation|column|function) "[A-Za-z0-9_.]+" does not exist|permission denied for (?:function|table|schema) [A-Za-z0-9_.]+|cannot extract elements from a scalar|canceling statement due to statement timeout|invalid input syntax for type [a-z ]+', message)
    return ": " + match.group(0) if match else ""


def request(url, token, body=None):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), headers={
        "Authorization": "Bearer " + token, "Accept": "application/json", "Content-Type": "application/json", "User-Agent": "Lector-generator-deploy"})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        # Responses to secret installation may contain secrets: never print them.
        detail = sql_diagnostic(error.read()) if url.endswith("/database/query") else ""
        raise RuntimeError(f"Remote request failed (HTTP {error.code}){detail}") from None


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
    workshop = env.get("GENERATOR_WORKSHOP") == "true"
    function = "lector-generator-workshop" if workshop else "lector-generator"
    token = env["SUPABASE_ACCESS_TOKEN"]
    base = f"https://api.supabase.com/v1/projects/{PROJECT}"
    def query(sql, read_only=False):
        return request(base + "/database/query", token, {"query": sql, "read_only": read_only})
    dependencies = query("select to_regclass('public.match_feed_analysis_snapshots') is not null as football_analysis, to_regclass('public.sport_feed_publications') is not null as hockey_publication", True)
    print(json.dumps({"generator_source_tables": dependencies}))
    sql = MIGRATION.read_text()
    prior = query(f"select statements from supabase_migrations.schema_migrations where version='{VERSION}'", True)
    if prior:
        if prior[0].get("statements") != [sql]:
            raise ValueError("Installed generator migration differs; create a new migration before changing it.")
    else:
        if "$lector_generator_sql$" in sql:
            raise ValueError("Unexpected SQL delimiter.")
        query("begin;\n" + sql + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{VERSION}','lector_generator',array[$lector_generator_sql${sql}$lector_generator_sql$]);\ncommit;")
    # Follow-up migrations are append-only; never alter the installed baseline
    # or clear the cumulative budget/account usage during an update.
    for migration in sorted(Path("supabase/migrations").glob("*_lector_generator_*.sql")):
        if migration.name.endswith("_lector_generator_workshop.sql") and not workshop:
            continue
        version, name = migration.stem.split("_", 1)
        followup = migration.read_text()
        prior = query(f"select statements from supabase_migrations.schema_migrations where version='{version}'", True)
        if prior:
            if prior[0].get("statements") != [followup]:
                raise ValueError("Installed follow-up migration differs.")
        else:
            if "$lector_generator_sql$" in followup:
                raise ValueError("Unexpected SQL delimiter.")
            query("begin;\n" + followup + f"\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('{version}','{name}',array[$lector_generator_sql${followup}$lector_generator_sql$]);\ncommit;")
    # The helper is deliberately unavailable to the management API's restricted
    # read-only role. This SELECT uses the installer role without changing ACLs.
    source_check = query("select jsonb_array_length(public.lector_generator_sources((now() at time zone 'Europe/Paris')::date,'Europe/Paris')) as source_count")
    print(json.dumps({"generator_source_check": source_check}))
    script = "tool/regression_generator_remote.ts" if env.get("GENERATOR_UPDATE") == "true" else "tool/benchmark_lector_generator.ts"
    if workshop:
        script = "tool/benchmark_generator_workshop.ts"
    subprocess.run(["deno", "run", "--allow-env=OPENAI_API_KEY,SUPABASE_ACCESS_TOKEN,GITHUB_ACTIONS", "--allow-net=api.openai.com,api.supabase.com", "--allow-write=/tmp/lector-generator-model.txt,/tmp/lector-generator-comparison.json", script], check=True)
    model = Path("/tmp/lector-generator-model.txt").read_text().strip()
    if model not in MODELS:
        raise ValueError("No verified test model selected.")
    # Disable before redeploy. Preserve every existing football/hockey secret.
    config = {"OPENAI_API_KEY": env["OPENAI_API_KEY"], "LECTOR_OPENAI_MODEL": model, "LECTOR_GENERATOR_ENABLED": "false", "LECTOR_GENERATOR_USER_DAILY_LIMIT": "5", "LECTOR_GENERATOR_DAILY_LIMIT": "20"}
    if workshop:
        if model not in {"gpt-6.1-sol", "gpt-6-luna"}:
            raise ValueError("Workshop accepts only the requested GPT-6 comparison pair.")
        config = {"OPENAI_API_KEY": env["OPENAI_API_KEY"], "LECTOR_WORKSHOP_MODEL": model, "LECTOR_WORKSHOP_ENABLED": "false", "LECTOR_WORKSHOP_COMPARE_MODELS": "true"}
    request(base + "/secrets", token, [{"name": n, "value": v} for n, v in config.items()])
    subprocess.run(["supabase", "functions", "deploy", function, "--project-ref", PROJECT, "--use-api", "--no-verify-jwt"], check=True)
    remote = request(base + "/functions/" + function, token)
    if remote.get("status") != "ACTIVE" or remote.get("verify_jwt") is not False:
        raise RuntimeError("Generator function deployment was not verified.")
    # Check anonymous requests fail before switching on paid interpretations.
    req = urllib.request.Request(f"https://{PROJECT}.supabase.co/functions/v1/{function}", data=b'{}', headers={"Content-Type":"application/json"})
    try:
        urllib.request.urlopen(req, timeout=30)
        raise RuntimeError("Anonymous generator request was unexpectedly accepted.")
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise RuntimeError("Anonymous protection check failed.") from None
    request(base + "/secrets", token, [{"name":"LECTOR_WORKSHOP_ENABLED" if workshop else "LECTOR_GENERATOR_ENABLED","value":"true"}])
    print(json.dumps({"function":function,"active":True,"model":model,"compare_models":workshop,"user_daily_limit":None if workshop else 5,"global_daily_limit":None if workshop else 20,"test_envelope_usd":None if workshop else 3,"migration_sha256":hashlib.sha256(sql.encode()).hexdigest()}))


if __name__ == "__main__":
    main()
