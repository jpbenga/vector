"""Build the exact main revision on the existing runner, with public config only."""
import os
import subprocess
from pathlib import Path
from deploy_controlled_generator_release import api, BASE, ROOT, REPOSITORY


def main():
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if (os.environ.get('GITHUB_REPOSITORY') != REPOSITORY
        or os.environ.get('GITHUB_REF') != 'refs/heads/main'
        or os.environ.get('GITHUB_SHA') != revision
        or os.environ.get('LECTOR_APPROVED_RELEASE') != revision):
        raise ValueError('Build must use the exact approved main revision.')
    runs = api('https://api.github.com/repos/' + REPOSITORY
               + '/actions/workflows/ci.yml/runs?head_sha=' + revision + '&per_page=100',
               os.environ['GH_TOKEN'])
    if not any(r.get('head_sha') == revision and r.get('head_branch') == 'main'
               and r.get('event') == 'push' and r.get('conclusion') == 'success'
               for r in runs.get('workflow_runs', [])):
        raise ValueError('Successful main CI required before building.')
    keys = api(BASE + '/api-keys', os.environ['SUPABASE_ACCESS_TOKEN'])
    public_key = next(k['api_key'] for k in keys if k['name'] == 'anon')
    envfile = ROOT / '.env'
    if envfile.exists():
        raise ValueError('Refuse to overwrite an existing environment file.')
    try:
        envfile.write_text('SUPABASE_URL=https://ednvvxxvlawaagjyshkj.supabase.co\n'
                           + 'SUPABASE_ANON_KEY=' + public_key + '\n')
        envfile.chmod(0o600)
        subprocess.run(['python3', 'tool/prepare_controlled_release.py', '--build',
                        '--output', 'build/controlled-release'], check=True)
    finally:
        envfile.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
