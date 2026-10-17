"""Package an immutable local release. No deploy, collection, DB access or AI call."""
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS = [
    '20261013210000_generator_domestic_form_projection.sql',
    '20261013220000_generator_exploration_archive_reader.sql',
    '20261014090000_generator_request_audit.sql',
    '20261014160000_hockey_publication_storage.sql',
    '20261014190000_generator_discovery_publication_parity.sql',
    '20261015090000_generator_composition_contract_audit.sql',
]
FUNCTIONS = [
    'lector-generator', 'lector-generator-workshop', 'api-football-sync',
    'build-match-feed-snapshot', 'daily-football-sync', 'ops-worker', 'build-feed-delivery',
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', action='store_true', help='Compile locally with public config only')
    args = parser.parse_args()
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if not re.fullmatch(r'[a-f0-9]{40}', revision):
        raise ValueError('A full immutable Git revision is required')
    if subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--', 'lib', 'supabase', 'tool', '.github', 'vercel.json'], cwd=ROOT).returncode:
        raise ValueError('Commit the reviewed source before packaging')
    untracked = subprocess.check_output(['git','ls-files','--others','--exclude-standard','lib','supabase'],cwd=ROOT,text=True).strip()
    if untracked:
        raise ValueError('Untracked application/server source cannot enter a release')
    target = args.output.resolve()
    if target == ROOT or not target.is_relative_to(ROOT/'build'):
        raise ValueError('Use a dedicated build subdirectory')
    target.mkdir(parents=True,exist_ok=True)
    definitions = {
        'APP_ENV':'production', 'MATCH_FEED_SOURCE':'auto', 'LECTOR_GENERATOR_UI':'true',
        'LECTOR_GENERATOR_ENDPOINT':'lector-generator-workshop', 'LECTOR_RELEASE_REVISION':revision,
        'APP_PUBLIC_URL':'https://lector-sports.vercel.app/',
    }
    generator_revision = os.environ.get('LECTOR_GENERATOR_REVISION', revision)
    if not re.fullmatch(r'[a-f0-9]{40}', generator_revision):
        raise ValueError('An immutable Generator API compatibility revision is required')
    if generator_revision != revision:
        # A UI/data-reader release may keep the existing Generator backend.
        # Refuse that path if any of its handler or contract source changed.
        if subprocess.run(['git','diff','--quiet',generator_revision,revision,'--',
                           'supabase/functions/_shared/generator',
                           'supabase/functions/lector-generator-workshop',
                           'supabase/functions/lector-generator'],cwd=ROOT).returncode:
            raise ValueError('Generator backend changed; publish a matching backend instead')
    definitions['LECTOR_GENERATOR_REVISION'] = generator_revision
    if args.build:
        public = {}
        for line in (ROOT/'.env').read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                name,value=line.split('=',1)
                if name.strip() in ('SUPABASE_URL','SUPABASE_ANON_KEY'):
                    public[name.strip()]=value.strip().strip('\"\'')
        if public.get('SUPABASE_URL') != 'https://ednvvxxvlawaagjyshkj.supabase.co' or not public.get('SUPABASE_ANON_KEY'):
            raise ValueError('Expected public project configuration is missing')
        # No server/provider key, account allowlist or private environment is compiled.
        # The same recipe is used by local packaging and Vercel. No divergent
        # static hockey/demo bundle is produced by a principal release.
        subprocess.run(['bash','tool/build_web_staging.sh'], cwd=ROOT, check=True,
            env={**os.environ, **definitions, **public,
                 'LECTOR_BUILD_OUTPUT':str(target), 'LECTOR_SKIP_PUB':'true'})
        for required in ['index.html','main.dart.js','flutter_bootstrap.js','assets/AssetManifest.bin.json']:
            if not (target/required).is_file():
                raise ValueError('Build artifact incomplete: '+required)
        # Missing JSON stays HTTP 404. Only known application routes use the SPA.
        config=json.loads((ROOT/'vercel.json').read_text())
        config.update({'buildCommand':None,'installCommand':None,'outputDirectory':'.'})
        (target/'vercel.json').write_text(json.dumps(config,indent=2)+'\n')
    # A concurrently changed checkout must never receive an immutable receipt.
    if subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() != revision:
        raise ValueError('Source revision changed while packaging; rebuild the final committed revision')
    if subprocess.run(['git','diff','--quiet','HEAD','--','lib','supabase','tool','.github','vercel.json'],cwd=ROOT).returncode:
        raise ValueError('Source changed while packaging; do not publish this artifact')
    sources = subprocess.check_output(['git','ls-files','lib','supabase/functions','tool','.github/workflows','vercel.json'],cwd=ROOT,text=True).splitlines()
    report = {
        'revision':revision,'builtLocally':args.build,'published':False,
        'defaultCanaryEnabled':False,'clientDefines':definitions,
        'serverRequiredConfiguration':['LECTOR_RELEASE_REVISION','LECTOR_GENERATOR_CANARY_ENABLED','LECTOR_GENERATOR_CANARY_USER_IDS','LECTOR_GENERATOR_CANARY_EMAILS'],
        'migrationOrder':[{'path':'supabase/migrations/'+m,'sha256':digest(ROOT/'supabase/migrations'/m)} for m in MIGRATIONS],
        'functions':FUNCTIONS,'sourceSha256':{p:digest(ROOT/p) for p in sources},
        'webSha256':{str(p.relative_to(target)):digest(p) for p in sorted(target.rglob('*')) if p.is_file() and p.name!='release.json'},
        'productionGates':['explicit publication confirmation','verified backup and isolated restore','quota capacity checked','green CI for this SHA','fresh seven-league hockey publication','14 current heads per sport','account and revision gate verified'],
    }
    (target/'release.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'revision':revision,'builtLocally':args.build,'published':False,'manifest':str(target/'release.json')}))


if __name__ == '__main__':
    main()
