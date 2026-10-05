import importlib.util
import pathlib
import unittest

path = pathlib.Path(__file__).resolve().parents[1] / "deploy_supabase_remote.py"
spec = importlib.util.spec_from_file_location("remote", path)
remote = importlib.util.module_from_spec(spec)
spec.loader.exec_module(remote)


class RemoteDeploymentTests(unittest.TestCase):
    def environment(self):
        return {"GITHUB_ACTIONS": "true", "GITHUB_REF": "refs/heads/main",
                "GITHUB_REPOSITORY": "jpbenga/vector", "GITHUB_SHA": "abc",
                "SUPABASE_ACCESS_TOKEN": "test-only", "GH_TOKEN": "test-only",
                "DEPLOY_FUNCTION": "sync-live-matches"}

    def test_missing_secret_fails_without_a_keychain_fallback(self):
        env = self.environment()
        del env["SUPABASE_ACCESS_TOKEN"]
        with self.assertRaisesRegex(ValueError, "No keychain"):
            remote.validate_environment(env)

    def test_multisport_branch_and_unknown_functions_are_rejected(self):
        env = self.environment()
        env["GITHUB_REF"] = "refs/heads/codex/multisport-hockey"
        with self.assertRaises(ValueError): remote.validate_environment(env)
        env = self.environment()
        env["DEPLOY_FUNCTION"] = "hockey-sync"
        with self.assertRaises(ValueError): remote.validate_environment(env)

    def test_only_ci_of_the_selected_main_revision_can_unlock_deployment(self):
        good = {"path": ".github/workflows/ci.yml", "head_sha": "abc",
                "head_branch": "main", "event": "push", "conclusion": "success"}
        remote.require_successful_ci([good], "abc")
        for key, value in [("head_sha", "older"), ("conclusion", "failure"),
                           ("head_branch", "codex/multisport-hockey"),
                           ("event", "pull_request")]:
            with self.assertRaises(ValueError):
                remote.require_successful_ci([{**good, key: value}], "abc")

    def test_all_functions_is_a_fixed_football_allowlist(self):
        env = self.environment()
        env["DEPLOY_FUNCTION"] = "all-football"
        self.assertEqual(remote.validate_environment(env), remote.FUNCTIONS)


if __name__ == "__main__": unittest.main()
