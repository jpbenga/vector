from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('hockey_alarm', Path(__file__).parents[1]/'sports/check_hockey_publication_health.py')
alarm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(alarm)


class HockeyFreshnessAlarmTest(unittest.TestCase):
    now = datetime(2026, 10, 14, 0, 0, tzinfo=timezone.utc)

    def document(self, hours=1):
        stamp = (self.now-timedelta(hours=hours)).isoformat()
        days = [(self.now.date()+timedelta(days=i)).isoformat() for i in range(16)]
        return {'capturedAt': stamp, 'baseCapturedAt': stamp,
                'collectionId': 'verified', 'windowStart': '2026-10-07',
                'windowEnd': days[-1], 'competitionIds': list(alarm.LEAGUES),
                'heads': [{'day': d, 'capturedAt': stamp, 'collectionId': 'verified'} for d in days]}

    def test_alerts_before_the_unchanged_rejection_threshold(self):
        for age,status in ((1,'healthy'),(23.9,'healthy'),(24,'warning'),(30,'critical'),(36,'critical'),(36.01,'stale')):
            result=alarm.assess(self.document(age),self.now)
            self.assertEqual(result['status'],status)
            self.assertEqual(result['providerRequests'],0)
            self.assertEqual(result['paidModelCalls'],0)

    def test_quotes_or_enrichment_cannot_disguise_a_stale_base(self):
        d=self.document(); d['baseCapturedAt']=(self.now-timedelta(hours=40)).isoformat()
        self.assertEqual(alarm.assess(d,self.now)['status'],'stale')

    def test_every_day_must_point_to_the_same_verified_collection(self):
        d=self.document(); d['heads'][13]['collectionId']='older'
        result=alarm.assess(d,self.now)
        self.assertIn('delivery_heads_not_current',result['issues'])
        self.assertEqual(len(result['missingHeadDays']),1)

    def test_missing_league_invalid_timestamp_and_empty_source_fail_closed(self):
        for d in ({}, {**self.document(),'competitionIds':['57']}, {**self.document(),'capturedAt':'invalid'}):
            self.assertEqual(alarm.assess(d,self.now)['status'],'invalid')

    def test_paris_midnight_and_dst_are_calendar_based(self):
        now=datetime(2026,10,24,23,30,tzinfo=timezone.utc)
        d=self.document();stamp=now.isoformat()
        d.update(capturedAt=stamp,baseCapturedAt=stamp,windowStart='2026-10-24',windowEnd='2026-11-08')
        d['heads']=[{'day':(datetime(2026,10,25).date()+timedelta(days=i)).isoformat(),'capturedAt':stamp,'collectionId':'verified'} for i in range(14)]
        self.assertEqual(alarm.assess(d,now)['status'],'healthy')


if __name__=='__main__': unittest.main()
