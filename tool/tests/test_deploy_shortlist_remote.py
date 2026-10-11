import importlib.util
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
spec = importlib.util.spec_from_file_location('shortlist_remote', pathlib.Path(__file__).resolve().parents[1] / 'deploy_shortlist_remote.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ShortlistDeploymentTests(unittest.TestCase):
    def test_branch_secret_and_demo_function_are_required(self):
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/codex/multisport-hockey', 'GITHUB_REPOSITORY': 'jpbenga/vector', 'GITHUB_SHA': 'test', 'SUPABASE_ACCESS_TOKEN': 'test', 'GH_TOKEN': 'test'}
        module.validate_environment(env)
        for field, value in [('GITHUB_REF','refs/heads/main'), ('GITHUB_ACTIONS','false'), ('SUPABASE_ACCESS_TOKEN','')]:
            with self.assertRaises(ValueError): module.validate_environment({**env,field:value})
        self.assertEqual(module.FUNCTION,'lector-generator-workshop')
        self.assertEqual(module.MIGRATION.name,'20261011160000_lector_shortlist.sql')

if __name__ == '__main__':
    unittest.main()
