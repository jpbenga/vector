import pathlib
import sys
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import deploy_generator_conversation_remote as module


class ConversationDeployTests(unittest.TestCase):
    def environment(self):
        return {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/codex/multisport-hockey',
                'GITHUB_REPOSITORY': 'jpbenga/vector', 'GITHUB_SHA': 'abc',
                'SUPABASE_ACCESS_TOKEN': 'test', 'GH_TOKEN': 'test'}

    def test_demo_only_exact_ci_and_no_openai_key_needed(self):
        module.validate_environment(self.environment())
        self.assertEqual(module.FUNCTION, 'lector-generator-workshop')
        with self.assertRaises(ValueError):
            module.validate_environment({**self.environment(), 'GITHUB_REF': 'refs/heads/main'})
        with self.assertRaises(ValueError):
            module.require_ci([{'path': '.github/workflows/ci.yml', 'head_sha': 'old', 'head_branch': 'codex/multisport-hockey', 'event': 'push', 'conclusion': 'success'}], 'abc')

    def test_no_local_keychain_fallback(self):
        with self.assertRaisesRegex(ValueError, 'No keychain'):
            module.validate_environment({**self.environment(), 'SUPABASE_ACCESS_TOKEN': ''})


if __name__ == '__main__':
    unittest.main()
