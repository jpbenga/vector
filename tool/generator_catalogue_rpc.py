"""Read two stable catalogue RPCs with the same server role as the Generator.

Management read_only runs as supabase_read_only_user, which deliberately cannot
execute these server-only functions. No ACL change, SQL mutation or key export.
"""
import json
import urllib.error
import urllib.request
from deploy_controlled_generator_release import api, BASE, PROJECT, NoRedirect

class ServerCatalogueReader:
    RPCS = frozenset(('lector_generator_day_manifest','lector_generator_day_page'))

    def __init__(self, management_token):
        self.management_token = management_token
        self._key = None

    def read(self, name, parameters):
        if name not in self.RPCS:
            raise ValueError('Only stable catalogue reader RPCs are allowed')
        if self._key is None:
            keys = api(BASE + '/api-keys', self.management_token)
            self._key = next((k.get('api_key') for k in keys if k.get('name') == 'service_role'), None)
            if not self._key:
                raise ValueError('Server catalogue credential unavailable; stop verification')
        request = urllib.request.Request(
            'https://' + PROJECT + '.supabase.co/rest/v1/rpc/' + name,
            data=json.dumps(parameters).encode(), method='POST',
            headers={'Authorization':'Bearer ' + self._key,'apikey':self._key,
                     'Content-Type':'application/json','Accept':'application/json'})
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError('Server catalogue reader failed (HTTP ' + str(error.code) + ')') from None
