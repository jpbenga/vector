"""Regression: a release must never ship a publication the app will reject."""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sports'))
from publication_health import require_current_hockey_publication


class HockeyPublicationHealthTest(unittest.TestCase):
    now = datetime(2026, 10, 11, 0, 14, tzinfo=timezone.utc)

    def publication(self, age=timedelta(hours=1)):
        return {'sport': 'hockey', 'schemaVersion': 1,
                'capturedAt': (self.now-age).isoformat(),
                'windowStart': '2026-10-04', 'windowEnd': '2026-10-24'}

    def test_incident_snapshot_rejected_and_real_refresh_accepted(self):
        old = self.publication()
        old['capturedAt'] = '2026-10-09T12:04:07.399Z'
        with self.assertRaisesRegex(ValueError, 'Publication hockey périmée'):
            require_current_hockey_publication(old, self.now)
        require_current_hockey_publication(self.publication(), self.now)

    def test_enrichment_cannot_disguise_an_expired_calendar(self):
        payload = self.publication()
        payload['baseCapturedAt'] = (self.now-timedelta(hours=40)).isoformat()
        with self.assertRaisesRegex(ValueError, 'baseCapturedAt'):
            require_current_hockey_publication(payload, self.now)

    def test_real_age_boundary_and_missing_timestamps(self):
        require_current_hockey_publication(self.publication(timedelta(hours=36)), self.now)
        for age in (timedelta(hours=36, seconds=1), timedelta(seconds=-31)):
            with self.assertRaises(ValueError):
                require_current_hockey_publication(self.publication(age), self.now)
        for stamp in (None, 'invalid', '2026-10-11T00:00:00'):
            payload = self.publication()
            payload['capturedAt'] = stamp
            with self.assertRaises(ValueError):
                require_current_hockey_publication(payload, self.now)

    def test_window_uses_paris_day_not_utc_day(self):
        now = datetime(2026, 10, 10, 23, 30, tzinfo=timezone.utc)
        payload = self.publication()
        payload['windowEnd'] = '2026-10-10'
        with self.assertRaisesRegex(ValueError, 'Paris day'):
            require_current_hockey_publication(payload, now)


if __name__ == '__main__':
    unittest.main()
