import pathlib
import sys
import unittest
import copy
import io
import json
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import deploy_hockey_odds_remote as deploy
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"sports"))
from publish_sport_feed import verify_publication

class HockeyOddsDeployTests(unittest.TestCase):
    def test_install_is_hockey_and_demo_only_and_requires_branch_ci(self):
        self.assertEqual(deploy.FUNCTIONS,('sync-hockey-odds','lector-generator-workshop'))
        env={'GITHUB_ACTIONS':'true','GITHUB_REF':'refs/heads/codex/multisport-hockey','GITHUB_REPOSITORY':'jpbenga/vector','GITHUB_SHA':'abc','GH_TOKEN':'test','SUPABASE_ACCESS_TOKEN':'test'}
        deploy.validate_environment(env)
        with self.assertRaises(ValueError): deploy.validate_environment({**env,'GITHUB_REF':'refs/heads/main'})
        with self.assertRaises(ValueError): deploy.require_ci([], 'abc')

class QuoteProjectionTests(unittest.TestCase):
    def setUp(self):
        self.base={'sport':'hockey','capturedAt':'2026-10-09T12:00:00Z','collectionId':'source','items':[{'id':'100','competitionId':'35','season':'2026','startsAt':'2026-10-10T18:00:00Z','home':{'id':'2'},'away':{'id':'3'},'readings':[{'id':'form','value':1}]}]}
        self.priced=copy.deepcopy(self.base)
        self.priced['items'][0].update(quotes=[{'decimalOdds':2.1}],quotesCollectedAt='2026-10-09T16:33:00Z')

    def transport(self, value):
        return patch('publish_sport_feed.urllib.request.urlopen',side_effect=[io.BytesIO(json.dumps(self.base).encode()),io.BytesIO(json.dumps(value).encode())])

    def test_only_prices_hydrate_the_verified_immutable_export(self):
        self.priced['items'][0]['readings']=[{'id':'changed'}]
        with self.transport(self.priced) as mock:
            result=verify_publication(self.base,{'SUPABASE_ANON_KEY':'public-test'})
        self.assertEqual(result['items'][0]['readings'],self.base['items'][0]['readings'])
        self.assertEqual(result['items'][0]['quotes'],self.priced['items'][0]['quotes'])
        requests=[json.loads(x.args[0].data) for x in mock.call_args_list]
        self.assertEqual([r['p_section'] for r in requests],['full','radar'])
        self.assertTrue(all(r['p_captured_at']==self.base['capturedAt'] for r in requests))

    def test_rejects_another_publication_or_fixture(self):
        for field,value in [('capturedAt','2026-10-09T13:00:00Z'),('collectionId','other')]:
            bad=copy.deepcopy(self.priced);bad[field]=value
            with self.transport(bad),self.assertRaises(ValueError):
                verify_publication(self.base,{'SUPABASE_ANON_KEY':'public-test'})
        for field,value in [('id','200'),('season','2025'),('startsAt','2026-10-11T18:00:00Z'),('home',{'id':'3'})]:
            bad=copy.deepcopy(self.priced);bad['items'][0][field]=value
            with self.transport(bad),self.assertRaises(ValueError):
                verify_publication(self.base,{'SUPABASE_ANON_KEY':'public-test'})

if __name__=='__main__': unittest.main()
