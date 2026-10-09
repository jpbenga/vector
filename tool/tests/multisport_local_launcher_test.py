"""Exercise launcher port collisions and server reuse without Flutter or API calls."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


LAUNCHER = Path(__file__).resolve().parents[1] / "run_multisport_local.sh"


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tool/sports").mkdir(parents=True)
        (self.root / "tool/sports/publish_sport_feed.py").write_text("from pathlib import Path\nPath('publication-shared').touch()\n")
        (self.root / "bin").mkdir()
        (self.root / "var/sports/hockey").mkdir(parents=True)
        (self.root / ".env").touch()
        shutil.copy(LAUNCHER, self.root / "tool/run_multisport_local.sh")
        self.stub("deno", '#!/bin/bash\necho invoked > "$TRACE_DENO"\nexit 99\n')
        self.stub(
            "lsof",
            '#!/bin/bash\n'
            'for arg; do\n'
            '  if [[ "$arg" == "-iTCP:$BUSY_PORT" || "$arg" == "-iTCP:$FEED_PORT" ]]; then\n'
            '    echo 123; exit 0\n'
            '  fi\n'
            'done\nexit 1\n',
        )
        (self.root / "tool/run_web_with_env.sh").write_text(
            '#!/bin/bash\n'
            'python3 - <<\'PY\'\n'
            'import os,json\n'
            'from pathlib import Path\n'
            'Path(os.environ["TRACE_APP"]).write_text(json.dumps({k:os.environ[k] for k in '
            '["APP_PUBLIC_URL","SPORT_FEED_BASE_URL","WEB_HOSTNAME"]}))\n'
            'PY\n'
        )
        self.env = {
            **os.environ,
            "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"],
            "TRACE_DENO": str(self.root / "deno-called"),
            "TRACE_APP": str(self.root / "app-called"),
            "APP_PUBLIC_URL": "http://192.168.0.46:8099/",
            "BUSY_PORT": "",
            "FEED_PORT": "",
        }

    def stub(self, name, content):
        path = self.root / "bin" / name
        path.write_text(content)
        path.chmod(0o755)

    def serve(self, received):
        data = json.dumps(received).encode()

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        def cleanup():
            server.shutdown()
            server.server_close()
            thread.join()

        self.addCleanup(cleanup)
        self.env["FEED_PORT"] = str(server.server_port)
        self.env["SPORT_PREVIEW_PORT"] = str(server.server_port)

    def run_launcher(self, port="8191"):
        return subprocess.run(
            ["bash", "tool/run_multisport_local.sh", port, "release"],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
        )

    def test_reuses_matching_publication_and_uses_same_origin_for_oauth(self):
        publication = {
            "schemaVersion": 1,
            "sport": "hockey",
            "collectionId": "current-project",
            "competitions": [{"id": "57"}],
            "items": [],
        }
        (self.root / "var/sports/hockey/published.json").write_text(
            json.dumps(publication)
        )
        self.serve(publication)
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("aucune nouvelle collecte", result.stdout)
        self.assertTrue((self.root / "publication-shared").exists())
        self.assertFalse((self.root / "deno-called").exists())
        config = json.loads((self.root / "app-called").read_text())
        self.assertEqual(config["APP_PUBLIC_URL"], "http://localhost:8191/")
        self.assertEqual(config["WEB_HOSTNAME"], "localhost")
        self.assertEqual(
            config["SPORT_FEED_BASE_URL"],
            "http://127.0.0.1:" + self.env["FEED_PORT"] + "/",
        )
        # Reusing the feed must not stop another invocation's server.
        second = self.run_launcher()
        self.assertEqual(second.returncode, 0, second.stderr)

    def test_occupied_web_port_stops_before_collection_and_flutter(self):
        self.env["BUSY_PORT"] = "8191"
        result = self.run_launcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("port de l'application 8191", result.stderr)
        self.assertFalse((self.root / "deno-called").exists())
        self.assertFalse((self.root / "app-called").exists())

    def test_foreign_hockey_server_is_not_reused_or_replaced(self):
        retained = {"sport": "hockey", "schemaVersion": 1, "items": [], "competitions": [57]}
        (self.root / "var/sports/hockey/published.json").write_text(json.dumps(retained))
        self.serve({**retained, "collectionId": "another-project"})
        result = self.run_launcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ne sert pas la publication de ce projet", result.stderr)
        self.assertFalse((self.root / "deno-called").exists())
        self.assertFalse((self.root / "app-called").exists())


if __name__ == "__main__":
    unittest.main()
