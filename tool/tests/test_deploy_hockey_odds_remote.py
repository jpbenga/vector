import pathlib
import sys
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import deploy_hockey_odds_remote as deploy

class HockeyOddsDeployTests(unittest.TestCase):
    def test_install_is_hockey_and_demo_only_and_requires_branch_ci(self):
        self.assertEqual(deploy.FUNCTIONS,('sync-hockey-odds','lector-generator-workshop'))
        env={'GITHUB_ACTIONS':'true','GITHUB_REF':'refs/heads/codex/multisport-hockey','GITHUB_REPOSITORY':'jpbenga/vector','GITHUB_SHA':'abc','GH_TOKEN':'test','SUPABASE_ACCESS_TOKEN':'test'}
        deploy.validate_environment(env)
        with self.assertRaises(ValueError): deploy.validate_environment({**env,'GITHUB_REF':'refs/heads/main'})
        with self.assertRaises(ValueError): deploy.require_ci([], 'abc')

if __name__=='__main__': unittest.main()
