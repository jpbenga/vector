#!/usr/bin/env python3
"""Approved release only: no model calls, no legacy endpoint replacement."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.error
import urllib.request

PROJECT = 'ednvvxxvlawaagjyshkj'
REPOSITORY = 'jpbenga/vector'
BASE = 'https://api.supabase.com/v1/projects/' + PROJECT
ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = ('lector-generator-workshop', 'api-football-sync',
             'build-match-feed-snapshot', 'daily-football-sync', 'ops-worker',
             'build-feed-delivery')
MIGRATIONS = ('20261013210000_generator_domestic_form_projection.sql',
              '20261013220000_generator_exploration_archive_reader.sql',
              '20261014090000_generator_request_audit.sql',
              '20261014160000_hockey_publication_storage.sql',
              '20261014190000_generator_discovery_publication_parity.sql')
DISCOVERY_MIGRATION = MIGRATIONS[-1]
PREREQUISITES = ('20261010090000', '20261011200000', '20261009120000',
                 '20261009170000', '20261011050000')
# Lookup the approved account without publishing its email or auth identifier.
ACCOUNT_HASH = 'f8cc0f040302bd2eace084b05d44c7b1ea6f8e79ae34b6c3ff24f1042a2f5169'
RPC_BASELINE = {
    'lector_generator_cleanup()': '3148627bf729e3c1058136a25fec8e5434b520278c10ba87213f53a6eec26a8f',
    'lector_generator_day_page(date,text,jsonb,jsonb)': 'b9f907e18d7d27751d5ebd3c057789eef32fde9a8cd1326ec7ce3d328e568a35',
}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None

def api(url, token, body=None):
    request = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(),
        headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json',
                 'Accept': 'application/json', 'User-Agent': 'Lector-controlled-release'})
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=120) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raise RuntimeError('Management request failed (HTTP ' + str(error.code) + ')') from None

def validate_environment(env, checked_out):
    revision = env.get('LECTOR_APPROVED_RELEASE', '')
    operation = env.get('LECTOR_RELEASE_OPERATION')
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('GITHUB_REF') != 'refs/heads/main'
        or env.get('GITHUB_REPOSITORY') != REPOSITORY):
        raise ValueError('Trusted main workflow required.')
    if not re.fullmatch('[a-f0-9]{40}', revision) or checked_out != revision or env.get('GITHUB_SHA') != revision:
        raise ValueError('Workflow, checkout and approved revision must be identical.')
    if operation not in ('install', 'activate', 'disable'):
        raise ValueError('Invalid operation.')
    if not env.get('SUPABASE_ACCESS_TOKEN') or not env.get('GH_TOKEN'):
        raise ValueError('Existing workflow credentials required.')
    return revision, operation

def migration_plan(installed, files):
    by_version = {row['version']: row for row in installed}
    if not all(version in by_version for version in PREREQUISITES):
        raise ValueError('Missing migration prerequisite.')
    pending = []
    for name, sql in files:
        version = name.split('_', 1)[0]
        row = by_version.get(version)
        if row and row.get('statements') != [sql]:
            raise ValueError('Installed migration body differs: ' + version)
        if not row:
            pending.append((name, sql))
    # Only an installed prefix may be extended; holes still require review.
    if pending and pending != files[len(files) - len(pending):]:
        raise ValueError('Noncontiguous installation requires review.')
    return pending

def legacy_source_hash():
    # Secret updates also bump function version metadata. Compare source,
    # without replacing the endpoint or downloading into the repository.
    with tempfile.TemporaryDirectory(prefix='lector-legacy-check-') as directory:
        subprocess.run(['supabase', 'functions', 'download', 'lector-generator',
                        '--project-ref', PROJECT, '--use-api', '--workdir', directory], check=True)
        source = Path(directory) / 'supabase/functions'
        files = sorted(p for p in source.rglob('*') if p.is_file())
        if not files:
            raise ValueError('Legacy source download is empty.')
        return {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

def main():
    revision, operation = validate_environment(os.environ,
        subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip())
    token = os.environ['SUPABASE_ACCESS_TOKEN']
    gh = os.environ['GH_TOKEN']
    runs = api('https://api.github.com/repos/' + REPOSITORY + '/actions/workflows/ci.yml/runs?head_sha=' + revision + '&per_page=100', gh)
    if not any(row.get('head_sha') == revision and row.get('head_branch') == 'main'
               and row.get('event') == 'push' and row.get('conclusion') == 'success'
               for row in runs.get('workflow_runs', [])):
        raise ValueError('Successful CI for this exact main SHA is required.')
    def query(sql, read_only=True):
        return api(BASE + '/database/query', token, {'query': sql, 'read_only': read_only})
    def secrets(values):
        api(BASE + '/secrets', token, [{'name': key, 'value': value} for key, value in values.items()])
    if operation == 'disable':
        secrets({'LECTOR_GENERATOR_CANARY_ENABLED': 'false'})
        receipt = {'revision': revision, 'operation': operation, 'canary_enabled': False,
                   'model_calls': 0, 'legacy_endpoint_replaced': False}
    else:
        users = query("select id::text, email_confirmed_at is not null as confirmed from auth.users where encode(extensions.digest(lower(email),'sha256'),'hex')='" + ACCOUNT_HASH + "'")
        if len(users) != 1 or not users[0].get('confirmed'):
            raise ValueError('The sole approved account must exist and be confirmed.')
        owner = users[0]['id']
        files = [(name, (ROOT / 'supabase/migrations' / name).read_text()) for name in MIGRATIONS]
        versions = PREREQUISITES + tuple(name.split('_', 1)[0] for name in MIGRATIONS)
        installed = query('select version,statements from supabase_migrations.schema_migrations where version in (' + ','.join("'" + v + "'" for v in versions) + ')')
        pending = migration_plan(installed, files)
        before = {row['slug']: row for row in api(BASE + '/functions', token)}
        legacy = before.get('lector-generator')
        if not legacy or legacy.get('status') != 'ACTIVE':
            raise ValueError('The existing legacy endpoint must remain active.')
        if any(before.get(f, {}).get('status') != 'ACTIVE' or before[f].get('verify_jwt') is not False for f in FUNCTIONS):
            raise ValueError('Reviewed deployment configuration differs from the installed functions.')
        if operation == 'install':
            legacy_hash = legacy_source_hash()
            secrets({'LECTOR_GENERATOR_CANARY_ENABLED': 'false',
                     'LECTOR_GENERATOR_CANARY_USER_IDS': owner,
                     'LECTOR_GENERATOR_CANARY_EMAILS': '', 'LECTOR_RELEASE_REVISION': revision})
            if any(name in MIGRATIONS[:2] for name, _ in pending):
                current = query("select p.oid::regprocedure::text as rpc, encode(extensions.digest(pg_get_functiondef(p.oid),'sha256'),'hex') as hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('lector_generator_cleanup','lector_generator_day_page')")
                if {row['rpc'].removeprefix('public.'): row['hash'] for row in current} != RPC_BASELINE:
                    raise ValueError('Installed RPCs differ from the verified backup.')
            if any(name == '20261014160000_hockey_publication_storage.sql' for name, _ in pending):
                prior = query("select encode(extensions.digest(pg_get_functiondef('public.publish_sport_feed(jsonb,jsonb)'::regprocedure),'sha256'),'hex') as hash")
                if prior != [{'hash': '1261d49d5554d82274f300485ee5bfd5c1fe1a9d6cfc387f3735fffbaa4f42e6'}]:
                    raise ValueError('Hockey writer differs from the reviewed backup.')
            if any(name == DISCOVERY_MIGRATION for name, _ in pending):
                prior = query("select encode(extensions.digest(pg_get_functiondef('public.lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb)'::regprocedure),'sha256'),'hex') as hash")
                if prior != [{'hash': '99fe6aa743a617eca54723570688577613d872d1a6823724c849267fdeec3826'}]:
                    raise ValueError('Discovery reader differs from the incident baseline.')
            if pending:
                sql = "begin; select pg_advisory_xact_lock(hashtext('lector-controlled-generator-release'));\n"
                for name, body in pending:
                    if '$lector_release_migration$' in body:
                        raise ValueError('Unexpected migration delimiter.')
                    version, label = name[:-4].split('_', 1)
                    sql += body + "\ninsert into supabase_migrations.schema_migrations(version,name,statements) values ('" + version + "','" + label + "',array[$lector_release_migration$" + body + "$lector_release_migration$]);\n"
                query(sql + 'commit;', False)
            deployed = ('lector-generator-workshop',) if pending and all(name == DISCOVERY_MIGRATION for name, _ in pending) else FUNCTIONS
            for function in deployed:
                subprocess.run(['supabase', 'functions', 'deploy', function, '--project-ref', PROJECT,
                                '--use-api', '--no-verify-jwt'], check=True)
            after = {row['slug']: row for row in api(BASE + '/functions', token)}
            if legacy_source_hash() != legacy_hash:
                raise ValueError('Legacy source unexpectedly changed.')
            if any(after.get(f, {}).get('status') != 'ACTIVE' or after[f].get('verify_jwt') is not False for f in FUNCTIONS):
                raise ValueError('Function deployment not verified.')
            acl = query("select bool_and(not has_function_privilege('anon',signature,'execute') and not has_function_privilege('authenticated',signature,'execute') and has_function_privilege('service_role',signature,'execute')) as safe from (values ('public.lector_generator_day_page(date,text,jsonb,jsonb)'),('public.lector_generator_exploration_read(uuid,uuid,uuid)'),('public.lector_generator_request_audit_read(uuid,uuid)'),('public.lector_generator_request_audit_write(uuid,uuid,jsonb)')) t(signature)")
            if acl != [{'safe': True}]:
                raise ValueError('Server-only RPC permissions not verified.')
            receipt = {'revision': revision, 'operation': operation, 'canary_enabled': False,
                       'migrations': [name for name, _ in files], 'functions': {f: after[f]['version'] for f in FUNCTIONS},
                       'deployed_functions': list(deployed),
                       'legacy_version': after['lector-generator']['version'], 'legacy_source_sha256': legacy_hash,
                       'legacy_endpoint_replaced': False, 'model_calls': 0}
        else:
            if pending:
                raise ValueError('Install migrations before activation.')
            secrets({'LECTOR_GENERATOR_CANARY_USER_IDS': owner, 'LECTOR_GENERATOR_CANARY_EMAILS': '',
                     'LECTOR_RELEASE_REVISION': revision, 'LECTOR_GENERATOR_CANARY_ENABLED': 'true'})
            receipt = {'revision': revision, 'operation': operation, 'canary_enabled': True,
                       'allowed_accounts': 1, 'legacy_endpoint_replaced': False, 'model_calls': 0}
    (ROOT / 'controlled-generator-release-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))

if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
