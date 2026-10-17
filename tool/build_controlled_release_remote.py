"""Build the exact main revision on the existing runner, with public config only."""
import os
import subprocess
import re
import urllib.request
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
    # OPTIONS only: no conversation, model call or account preference mutation.
    probe = urllib.request.Request('https://ednvvxxvlawaagjyshkj.supabase.co/functions/v1/lector-generator-workshop',
        headers={'apikey': public_key}, method='OPTIONS')
    with urllib.request.urlopen(probe, timeout=20) as response:
        generator_revision = response.headers.get('x-lector-release-revision', '')
    if not re.fullmatch(r'[a-f0-9]{40}', generator_revision):
        raise ValueError('Cannot confirm the current Generator API revision')
    if subprocess.run(['git','cat-file','-e',generator_revision+'^{commit}'],
                      stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode:
        subprocess.run(['git','fetch','--no-tags','--depth=1','origin',generator_revision],check=True)
    envfile = ROOT / '.env'
    if envfile.exists():
        raise ValueError('Refuse to overwrite an existing environment file.')
    try:
        envfile.write_text('SUPABASE_URL=https://ednvvxxvlawaagjyshkj.supabase.co\n'
                           + 'SUPABASE_ANON_KEY=' + public_key + '\n')
        envfile.chmod(0o600)
        subprocess.run(['python3', 'tool/prepare_controlled_release.py', '--build',
                        '--output', 'build/controlled-release'], check=True,
                       env={**os.environ,'LECTOR_GENERATOR_REVISION':generator_revision})
    finally:
        envfile.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
