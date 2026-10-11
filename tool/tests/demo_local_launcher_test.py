"""Launch the conversational UI with fake Flutter and forbid provider collection."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class DemoLocalLauncherTest(unittest.TestCase):
    def test_demo_flags_and_oauth_origin_without_any_collector(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tool").mkdir()
            (root / "bin").mkdir()
            for name in ("run_demo_local.sh", "run_web_with_env.sh"):
                shutil.copy(ROOT / "tool" / name, root / "tool" / name)
            (root / ".env").write_text(
                "SUPABASE_URL=https://example.supabase.co\n"
                "SUPABASE_ANON_KEY=public-test-key\n"
                "APP_PUBLIC_URL=http://192.168.0.46:8099/\n"
            )
            flutter = root / "bin/flutter"
            flutter.write_text(
                "#!/usr/bin/env python3\n"
                "import json,sys\n"
                "from pathlib import Path\n"
                "Path('flutter-arguments.json').write_text(json.dumps(sys.argv[1:]))\n"
            )
            flutter.chmod(0o755)
            deno = root / "bin/deno"
            deno.write_text("#!/bin/bash\ntouch collector-called\nexit 99\n")
            deno.chmod(0o755)
            lsof = root / "bin/lsof"
            lsof.write_text("#!/bin/bash\nexit 1\n")
            lsof.chmod(0o755)
            env = {
                **os.environ,
                "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
                "SPORT_FEED_BASE_URL": "http://localhost:8110/",
            }
            env.pop("LECTOR_WEB_DEVICE", None)
            result = subprocess.run(
                ["bash", "tool/run_demo_local.sh", "8192", "release"],
                cwd=root, env=env, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = json.loads((root / "flutter-arguments.json").read_text())
            self.assertEqual(args[:3], ["run", "-d", "web-server"])
            for expected in (
                "--dart-define=LECTOR_GENERATOR_UI=true",
                "--dart-define=LECTOR_GENERATOR_ENDPOINT=lector-generator-workshop",
                "--dart-define=APP_ENV=staging",
                "--dart-define=APP_PUBLIC_URL=http://localhost:8192/",
                "--dart-define=SPORT_FEED_BASE_URL=",
            ):
                self.assertIn(expected, args)
            self.assertFalse((root / "collector-called").exists())

    def test_occupied_port_stops_before_flutter_and_shows_existing_address(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tool").mkdir()
            (root / "bin").mkdir()
            shutil.copy(ROOT / "tool/run_demo_local.sh", root / "tool/run_demo_local.sh")
            lsof = root / "bin/lsof"
            lsof.write_text("#!/bin/bash\nexit 0\n")
            lsof.chmod(0o755)
            flutter = root / "bin/flutter"
            flutter.write_text("#!/bin/bash\ntouch flutter-called\n")
            flutter.chmod(0o755)
            env = {
                **os.environ,
                "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
            }
            result = subprocess.run(
                ["bash", "tool/run_demo_local.sh", "8192", "release"],
                cwd=root, env=env, capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("http://localhost:8192/", result.stderr)
            self.assertIn("aucun nouveau lancement", result.stderr)
            self.assertFalse((root / "flutter-called").exists())


if __name__ == "__main__":
    unittest.main()
