import json
import time
from pathlib import Path
import requests

BASE='http://127.0.0.1:8010'
PDF=Path('/Users/pranay/Projects/medpiper/insurance_app/tests/test_data/sample_insurance.pdf')
TXT=Path('/Users/pranay/Projects/medpiper/insurance_app/storage/documents/sample_auto_policy.txt')


def pr(label, resp):
    code = resp.status_code
    try:
        body = resp.json()
    except ValueError:
        body = resp.text[:5000]
    print(f"\n=== {label} ===")
    print(f"STATUS: {code}")
    if isinstance(body, (dict, list)):
        print(json.dumps(body, indent=2, default=str))
    else:
        print(body)
    return code, body

def req(method, path, **kwargs):
    return requests.request(method, BASE + path, **kwargs)

def auth(tok):
    return {"Authorization": f"Bearer {tok}"}

print('--- J02-J07 deep-dive probe ---')

resp=req('POST', '/user/anonymous')
_, body = pr('anon create A', resp)
owner_a = body.get('access_token')
if not owner_a:
    raise SystemExit('no anonymous token')

pr('consent current A', req('GET', '/consent/current', headers=auth(owner_a)))

with open(PDF, 'rb') as f:
    pr('upload missing consent', req('POST', '/documents/upload', headers=auth(owner_a), files={'files': ('sample_insurance.pdf', f, 'application/pdf')}, data={'processing_mode':'full'}))

with open(TXT, 'rb') as f:
    pr('upload txt invalid', req('POST', '/documents/upload', headers=auth(owner_a), files={'files': ('sample_auto_policy.txt', f, 'text/plain')}, data={'processing_consent': True, 'processing_consent_version':'v4-test'}))

with open(PDF, 'rb') as f:
    resp=req('POST', '/documents/upload', headers=auth(owner_a), files={'files': ('sample_insurance.pdf', f, 'application/pdf')}, data={'processing_consent': True, 'processing_consent_version':'v4-test'})
status, body = pr('upload valid', resp)
if status not in (200,202) or not body.get('documents'):
    raise SystemExit('valid upload failed')
doc_id = body['documents'][0]['id']

# replay
with open(PDF, 'rb') as f:
    pr('upload replay', req('POST', '/documents/upload', headers=auth(owner_a), files={'files': ('sample_insurance.pdf', f, 'application/pdf')}, data={'processing_consent': True, 'processing_consent_version':'v4-test'}))

# list
pr('documents list A', req('GET', '/documents?limit=20&page=1', headers=auth(owner_a)))

for i in range(1,16):
    status, payload = pr(f'status poll {i}', req('GET', f'/documents/{doc_id}/status', headers=auth(owner_a)))
    st = payload.get('status') if isinstance(payload, dict) else None
    if st not in ('received', 'uploading', 'uploaded', 'processing', 'deleting'):
        break
    time.sleep(2)

pr('summary', req('GET', f'/documents/{doc_id}/summary', headers=auth(owner_a)))
pr('field-citations', req('GET', f'/evidence/{doc_id}/field-citations', headers=auth(owner_a)))

payload_query = {
    'query': 'What is this document about?',
    'filters': {'document_id': doc_id},
    'request_id': None,
}
pr('query root /query', req('POST', '/query', headers={**auth(owner_a), 'Content-Type':'application/json'}, json=payload_query))
pr('query deprecated /documents/query', req('POST', '/documents/query', headers=auth(owner_a), data={'query':'What is this document about?', 'document_ids': doc_id}))

# offline/alt path: cross-owner checks
resp=req('POST', '/user/anonymous')
owner_b = resp.json().get('access_token')
pr('anon create B', resp)
pr('cross-owner list B', req('GET', '/documents?limit=20&page=1', headers=auth(owner_b)))
pr('cross-owner doc status B', req('GET', f'/documents/{doc_id}/status', headers=auth(owner_b)))

pr('claim-anonymous using anon token', req('POST', '/user/claim-anonymous', headers=auth(owner_a), json={'anonymous_token': owner_a}))

# processing consent history
pr('consent history A', req('GET', '/consent/history', headers=auth(owner_a)))

pr('health', req('GET', '/health'))

# store evidence summary line
print(f"\nDOC_ID={doc_id}\nOWNER_A={owner_a}\nOWNER_B={owner_b}")
