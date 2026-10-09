import importlib.util
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
spec = importlib.util.spec_from_file_location('generator_day_remote', pathlib.Path(__file__).resolve().parents[1] / 'deploy_generator_day_sources_remote.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DayReaderDeploymentTests(unittest.TestCase):
    def test_day_update_uses_only_existing_server_secret_and_demo_branch(self):
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/codex/multisport-hockey', 'GITHUB_REPOSITORY': 'jpbenga/vector', 'GITHUB_SHA': 'abc', 'SUPABASE_ACCESS_TOKEN': 'test', 'GH_TOKEN': 'test'}
        module.validate_environment(env)
        with self.assertRaises(ValueError):
            module.validate_environment({**env, 'GITHUB_REF': 'refs/heads/main'})
        self.assertEqual(module.FUNCTION, 'lector-generator-workshop')

    def test_sql_literal_keeps_quotes_inside_data(self):
        sql = module.page_sql('2026-10-10', "Europe/Paris'", [], [{'key': "football:1'"}])
        self.assertIn("'Europe/Paris'''", sql)
        self.assertIn("football:1''", sql)


if __name__ == '__main__':
    unittest.main()
