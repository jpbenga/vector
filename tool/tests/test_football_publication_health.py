import importlib.util
from pathlib import Path
from datetime import datetime,timezone
import unittest

spec=importlib.util.spec_from_file_location('football_health',Path(__file__).resolve().parents[1]/'sports/check_football_publication_health.py')
health=importlib.util.module_from_spec(spec);spec.loader.exec_module(health)

class FootballHealthTests(unittest.TestCase):
    def document(self):
        return {'parisDay':'2026-10-17','leagues':[{'id':'39','capturedAt':'2026-10-17T01:00:00Z','windowStart':'2026-10-17','windowEnd':'2026-10-31'}],'failedBatches':[],'stalledBatches':[]}
    def check(self,d):
        return health.assess(d,datetime(2026,10,17,12,tzinfo=timezone.utc))
    def test_current_publication_and_empty_failure_list_are_healthy(self):
        self.assertEqual(self.check(self.document())['status'],'healthy')
    def test_stale_missing_and_uncovered_are_distinct(self):
        for field,value,key in [('capturedAt',None,'missingLeagues'),('capturedAt','2026-10-15T01:00:00Z','staleLeagues'),('windowEnd','2026-10-16','uncoveredLeagues')]:
            d=self.document();d['leagues'][0][field]=value
            self.assertEqual(self.check(d)[key],['39'])
    def test_failed_and_stalled_batches_alert_even_with_a_current_publication(self):
        for field in ['failedBatches','stalledBatches']:
            d=self.document();d[field]=[{'id':'batch'}]
            result=self.check(d);self.assertEqual(result['status'],'attention');self.assertEqual(result[field],[{'id':'batch'}])
    def test_no_configuration_cannot_be_reported_healthy(self):
        d=self.document();d['leagues']=[];self.assertEqual(self.check(d)['status'],'attention')
