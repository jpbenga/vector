import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / 'deploy_controlled_generator_release.py'
spec = importlib.util.spec_from_file_location('controlled_release', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ControlledReleaseTests(unittest.TestCase):
    def test_wrong_revision_or_branch_refused(self):
        sha = 'a' * 40
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/main',
               'GITHUB_REPOSITORY': module.REPOSITORY, 'GITHUB_SHA': sha,
               'LECTOR_APPROVED_RELEASE': sha, 'LECTOR_RELEASE_OPERATION': 'install',
               'SUPABASE_ACCESS_TOKEN': 'test', 'GH_TOKEN': 'test'}
        self.assertEqual(module.validate_environment(env, sha), (sha, 'install'))
        with self.assertRaises(ValueError): module.validate_environment(env, 'b' * 40)
        with self.assertRaises(ValueError): module.validate_environment({**env, 'GITHUB_REF': 'refs/heads/other'}, sha)

    def test_installed_prefix_allowed_but_holes_or_differences_refused(self):
        prerequisite = [{'version': v} for v in module.PREREQUISITES]
        files = [('111_new.sql', 'first'), ('222_next.sql', 'second')]
        self.assertEqual(module.migration_plan(prerequisite, files), files)
        self.assertEqual(module.migration_plan(prerequisite + [{'version': '111', 'statements': ['first']}], files), files[1:])
        with self.assertRaises(ValueError): module.migration_plan(prerequisite + [{'version': '222', 'statements': ['second']}], files)
        with self.assertRaises(ValueError): module.migration_plan(prerequisite + [{'version': '111', 'statements': ['changed']}], files)
        all_installed = prerequisite + [{'version': '111', 'statements': ['first']}, {'version': '222', 'statements': ['second']}]
        self.assertEqual(module.migration_plan(all_installed, files), [])

    def test_legacy_endpoint_not_replaced(self):
        self.assertNotIn('lector-generator', module.FUNCTIONS)

    def test_contract_fix_only_publishes_workshop(self):
        self.assertEqual(module.functions_for_migrations([]), ('lector-generator-workshop',))
        self.assertEqual(module.functions_for_migrations([(module.CONTRACT_MIGRATION, 'sql')]), ('lector-generator-workshop',))
        self.assertEqual(module.functions_for_migrations([(module.DISCOVERY_MIGRATION, 'sql'), (module.CONTRACT_MIGRATION, 'sql')]), ('lector-generator-workshop',))
        self.assertEqual(module.DISCOVERY_MIGRATION, '20261014190000_generator_discovery_publication_parity.sql')

if __name__ == '__main__': unittest.main()
