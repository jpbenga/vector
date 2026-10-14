import contextlib
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import urllib.error
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import generator_catalogue_rpc as module

class ReaderTests(unittest.TestCase):
    def test_same_server_role_with_pinned_json_and_no_credential_output(self):
        response=io.StringIO(json.dumps({'total':18}))
        opener=unittest.mock.MagicMock()
        opener.open.return_value.__enter__.return_value=response
        stdout=io.StringIO()
        with patch.object(module,'api',return_value=[{'name':'anon','api_key':'public-example'},{'name':'service_role','api_key':'server-example'}]) as api,patch.object(module.urllib.request,'build_opener',return_value=opener),contextlib.redirect_stdout(stdout):
            reader=module.ServerCatalogueReader('management-example')
            self.assertEqual(reader.read('lector_generator_day_manifest',{'p_date':'2026-10-15','p_sports':['hockey']}),{'total':18})
            request=opener.open.call_args.args[0]
            self.assertEqual(request.get_header('Authorization'),'Bearer server-example')
            self.assertEqual(request.get_header('Apikey'),'server-example')
            self.assertTrue(request.full_url.endswith('/rest/v1/rpc/lector_generator_day_manifest'))
            self.assertEqual(json.loads(request.data),{'p_date':'2026-10-15','p_sports':['hockey']})
            api.assert_called_once_with(module.BASE+'/api-keys','management-example')
        self.assertEqual(stdout.getvalue(),'')

    def test_forbidden_write_rpc_rejected_before_key_lookup(self):
        with patch.object(module,'api') as api:
            with self.assertRaisesRegex(ValueError,'Only stable'):
                module.ServerCatalogueReader('management-example').read('lector_generator_work_commit',{})
            api.assert_not_called()

    def test_http_error_does_not_export_credentials_or_response_body(self):
        opener=unittest.mock.MagicMock()
        opener.open.side_effect=urllib.error.HTTPError('https://example.invalid',403,'private server-example detail',{},None)
        with patch.object(module,'api',return_value=[{'name':'service_role','api_key':'server-example'}]),patch.object(module.urllib.request,'build_opener',return_value=opener):
            with self.assertRaisesRegex(RuntimeError,r'^Server catalogue reader failed \(HTTP 403\)$'):
                module.ServerCatalogueReader('management-example').read('lector_generator_day_page',{'p_matches':[]})

if __name__=='__main__':unittest.main()
