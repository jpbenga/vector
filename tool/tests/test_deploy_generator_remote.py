import importlib.util
import pathlib
import unittest

path = pathlib.Path(__file__).resolve().parents[1] / "deploy_generator_remote.py"
spec = importlib.util.spec_from_file_location("generator_remote", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GeneratorDeploymentTests(unittest.TestCase):
    def environment(self):
        return {"GITHUB_ACTIONS":"true", "GITHUB_REF":"refs/heads/codex/multisport-hockey", "GITHUB_REPOSITORY":"jpbenga/vector", "GITHUB_SHA":"abc", "OPENAI_API_KEY":"test", "SUPABASE_ACCESS_TOKEN":"test", "GH_TOKEN":"test"}

    def test_only_the_multisport_branch_may_install(self):
        module.validate_environment(self.environment())
        with self.assertRaises(ValueError):
            module.validate_environment({**self.environment(), "GITHUB_REF":"refs/heads/main"})

    def test_missing_key_never_uses_local_credentials(self):
        env = self.environment()
        del env["OPENAI_API_KEY"]
        with self.assertRaisesRegex(ValueError, "No keychain"):
            module.validate_environment(env)

    def test_ci_requires_exact_branch_and_sha(self):
        good = {"path":".github/workflows/ci.yml", "head_sha":"abc", "head_branch":"codex/multisport-hockey", "event":"push", "conclusion":"success"}
        module.require_ci([good],"abc")
        with self.assertRaises(ValueError):
            module.require_ci([{**good,"head_sha":"old"}],"abc")

    def test_sql_diagnostics_never_echo_arbitrary_errors_or_values(self):
        self.assertEqual(module.sql_diagnostic('{"message":"relation \\"public.sport_feed_publications\\" does not exist"}'), ': relation "public.sport_feed_publications" does not exist')
        self.assertEqual(module.sql_diagnostic('{"message":"duplicate key contains sk-secret-test"}'), '')
        self.assertEqual(module.sql_diagnostic('sk-secret-test'), '')
        self.assertEqual(module.sql_diagnostic('{"message":"permission denied for function lector_generator_sources"}'), ': permission denied for function lector_generator_sources')
        self.assertEqual(module.sql_diagnostic('{"message":"cannot extract elements from a scalar"}'), ': cannot extract elements from a scalar')


if __name__ == "__main__":
    unittest.main()
