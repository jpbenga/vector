"""Deploy only the tested demo conversation function, without SQL or credential changes."""
import json
import os
import subprocess
import urllib.error
import urllib.request

from deploy_generator_remote import PROJECT, request, require_ci

FUNCTION = 'lector-generator-workshop'


def validate_environment(env):
    if (env.get('GITHUB_ACTIONS') != 'true'
            or env.get('GITHUB_REF') != 'refs/heads/codex/multisport-hockey'
            or env.get('GITHUB_REPOSITORY') != 'jpbenga/vector'):
        raise ValueError('This conversation update runs on the multisport GitHub branch only.')
    for name in ('SUPABASE_ACCESS_TOKEN', 'GH_TOKEN', 'GITHUB_SHA'):
        if not env.get(name):
            raise ValueError(f'Missing repository secret {name}. No keychain fallback.')


def main():
    env = os.environ
    validate_environment(env)
    runs = request(f"https://api.github.com/repos/jpbenga/vector/actions/workflows/ci.yml/runs?head_sha={env['GITHUB_SHA']}&per_page=100", env['GH_TOKEN'])
    require_ci(runs.get('workflow_runs', []), env['GITHUB_SHA'])
    # Only this existing function is bundled. No migrations, secret installation,
    # collectors, profile writes or paid account impersonation in this deployment.
    subprocess.run(['supabase', 'functions', 'deploy', FUNCTION, '--project-ref', PROJECT,
                    '--use-api', '--no-verify-jwt'], check=True)
    remote = request(f'https://api.supabase.com/v1/projects/{PROJECT}/functions/{FUNCTION}', env['SUPABASE_ACCESS_TOKEN'])
    if remote.get('status') != 'ACTIVE' or remote.get('verify_jwt') is not False:
        raise ValueError('Demo conversation deployment was not confirmed.')
    req = urllib.request.Request(f'https://{PROJECT}.supabase.co/functions/v1/{FUNCTION}', data=b'{"action":"chat"}',
                                 headers={'Content-Type': 'application/json'}, method='POST')
    try:
        urllib.request.urlopen(req, timeout=20)
        raise ValueError('Anonymous access was not rejected.')
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise ValueError('Unexpected anonymous endpoint response.') from None
    print(json.dumps({'function': FUNCTION, 'active': True, 'anonymous_status': 401,
                      'sql_migrations': 0, 'secrets_changed': False, 'paid_model_calls': 0,
                      'revision': env['GITHUB_SHA']}))


if __name__ == '__main__':
    main()
