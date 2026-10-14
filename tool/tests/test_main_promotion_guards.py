"""Offline admission checks: never deploy, collect, or call a model."""
import importlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))


class PromotionAdmissionTests(unittest.TestCase):
    def test_every_installer_refuses_writes_without_activation(self):
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/main',
               'GITHUB_REPOSITORY': 'jpbenga/vector', 'GITHUB_SHA': 'a' * 40,
               'SUPABASE_ACCESS_TOKEN': 'test', 'OPENAI_API_KEY': 'test',
               'GH_TOKEN': 'test', 'DEPLOY_FUNCTION': 'sync-live-matches'}
        for name in ('deploy_generator_remote', 'deploy_generator_scope_remote',
                     'deploy_generator_conversation_remote',
                     'deploy_supabase_remote', 'refresh_hockey_remote'):
            module = importlib.import_module(name)
            with self.subTest(installer=name):
                for flag in (None, '', 'false'):
                    with self.assertRaisesRegex(ValueError, 'post-backup'):
                        module.validate_environment({**env, 'LECTOR_REMOTE_WRITES_ENABLED': flag})
                module.validate_environment({**env, 'LECTOR_REMOTE_WRITES_ENABLED': 'true'})
                with self.assertRaises(ValueError):
                    module.validate_environment({**env, 'LECTOR_REMOTE_WRITES_ENABLED': 'true',
                                                 'GITHUB_REF': 'refs/heads/codex/multisport-hockey'})

    def test_promotion_disables_git_deployments_without_removing_spa_routes(self):
        config = json.loads((ROOT / 'vercel.json').read_text())
        self.assertIs(config['git']['deploymentEnabled'], False)
        self.assertEqual({r['source'] for r in config['rewrites']}, {'/sports/:sport', '/admin'})

    def build(self, revision, source_revision=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shim = root / 'flutter'
            shim.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$LECTOR_TEST_ARGUMENTS"\n')
            shim.chmod(0o700)
            args = root / 'args'
            env = {**os.environ, 'PATH': directory + ':' + os.environ['PATH'],
                   'SUPABASE_URL': 'https://public-test.supabase.co',
                   'SUPABASE_ANON_KEY': 'public-test', 'APP_PUBLIC_URL': 'https://test.example/',
                   'LECTOR_RELEASE_REVISION': revision, 'LECTOR_TEST_ARGUMENTS': str(args)}
            env.pop('APP_ENV', None)
            env.pop('VERCEL_GIT_COMMIT_SHA', None)
            if source_revision is not None:
                env['VERCEL_GIT_COMMIT_SHA'] = source_revision
            result = subprocess.run(['bash', 'tool/build_web_staging.sh'], cwd=ROOT,
                                    env=env, capture_output=True, text=True)
            return result, args.read_text().splitlines() if args.exists() else []

    def test_single_recipe_keeps_generator_and_compiles_the_exact_revision(self):
        result, args = self.build('a' * 40, 'a' * 40)
        self.assertEqual(result.returncode, 0, result.stderr)
        for define in ('APP_ENV=production', 'LECTOR_GENERATOR_UI=true',
                       'LECTOR_GENERATOR_ENDPOINT=lector-generator-workshop',
                       'LECTOR_RELEASE_REVISION=' + 'a' * 40):
            self.assertIn('--dart-define=' + define, args)
        self.assertFalse(any('SPORT_FEED_DEMO' in arg or 'FEED_DELIVERY_DEMO' in arg for arg in args))

    def test_invalid_or_mismatched_revision_fails_before_compilation(self):
        for revision, source in (('main', None), ('a' * 40, 'b' * 40)):
            result, args = self.build(revision, source)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(args, [])


if __name__ == '__main__':
    unittest.main()
