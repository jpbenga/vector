import importlib.util
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
spec=importlib.util.spec_from_file_location('generator_scope_remote',pathlib.Path(__file__).resolve().parents[1]/'deploy_generator_scope_remote.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ScopeDeploymentTests(unittest.TestCase):
    def environment(self):
        return {'GITHUB_ACTIONS':'true','GITHUB_REF':'refs/heads/codex/multisport-hockey','GITHUB_REPOSITORY':'jpbenga/vector','GITHUB_SHA':'abc','SUPABASE_ACCESS_TOKEN':'test','GH_TOKEN':'test'}

    def test_scope_update_needs_no_openai_key_or_keychain(self):
        module.validate_environment(self.environment())
        with self.assertRaisesRegex(ValueError,'No keychain'):
            module.validate_environment({**self.environment(),'SUPABASE_ACCESS_TOKEN':''})

    def test_main_cannot_deploy_demo_code(self):
        with self.assertRaises(ValueError):
            module.validate_environment({**self.environment(),'GITHUB_REF':'refs/heads/main'})

    def test_update_is_locked_to_tested_sha_and_demo_function(self):
        self.assertEqual(module.FUNCTION,'lector-generator-workshop')
        with self.assertRaises(ValueError):
            module.require_ci([{'path':'.github/workflows/ci.yml','head_sha':'old','head_branch':'codex/multisport-hockey','event':'push','conclusion':'success'}],'abc')

if __name__=='__main__':unittest.main()
