import pathlib
import sys
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import deploy_sport_publications_remote as deploy

class PublicationDeployTests(unittest.TestCase):
    def test_demo_only_functions_and_no_model_key(self):
        self.assertEqual(deploy.FUNCTIONS,('publish-sport-feed','lector-generator-workshop'))
        env={'GITHUB_ACTIONS':'true','GITHUB_REF':'refs/heads/codex/multisport-hockey','GITHUB_REPOSITORY':'jpbenga/vector','GITHUB_SHA':'abc','GH_TOKEN':'test','SUPABASE_ACCESS_TOKEN':'test'}
        deploy.validate_environment(env)
        with self.assertRaises(ValueError):
            deploy.validate_environment({**env,'GITHUB_REF':'refs/heads/main'})
        with self.assertRaises(ValueError):
            deploy.validate_environment({**env,'SUPABASE_ACCESS_TOKEN':''})

    def test_same_sha_ci_is_required(self):
        with self.assertRaises(ValueError):
            deploy.require_ci([{'path':'.github/workflows/ci.yml','head_sha':'old','head_branch':'codex/multisport-hockey','event':'push','conclusion':'success'}],'new')

if __name__=='__main__':unittest.main()
