import json
import time
import requests
from pathlib import Path

BASE='http://127.0.0.1:8010'
SAMPLES=[
    '/Users/pranay/Projects/medpiper/insurance_app/storage/documents/728b9a3c-b313-4ef7-bcaf-9a75372daa7b_e2e_policy_v2.pdf',
    '/Users/pranay/Projects/medpiper/insurance_app/storage/documents/97b5c3f7-5370-41c5-8e29-909c40be4cb6_journey_doc.pdf',
    '/Users/pranay/Projects/medpiper/insurance_app/storage/documents/8c2fca1c-212e-42bf-94ab-cd32f592ca93_e2e_policy.pdf',
]


def req(method,path,**kwargs):
    return requests.request(method, BASE+path, **kwargs)

def pr(label,resp):
    try:
      body=resp.json()
    except Exception:
      body=resp.text[:1200]
    print(f"\n=== {label} === status={resp.status_code}")
    if isinstance(body,(dict,list)):
      print(json.dumps(body,indent=2,default=str))
    else:
      print(body)
    return resp.status_code, body

def auth(tok):
    return {'Authorization':f'Bearer {tok}'}

# owner token
owner = req('POST','/user/anonymous').json()['access_token']

# upload each candidate, poll until terminal-ish, and capture non-happy states
for path in SAMPLES:
    with open(path,'rb') as f:
        code, body = pr(f'upload {Path(path).name}', req('POST','/documents/upload', headers=auth(owner), files={'files':(Path(path).name,f,'application/pdf')}, data={'processing_consent':True,'processing_consent_version':'v4-test'}))
    if code not in (200,202):
        continue
    doc_id = body['documents'][0]['id']

    for i in range(1,16):
      s,p = pr(f'status {Path(path).name} poll {i}', req('GET', f'/documents/{doc_id}/status', headers=auth(owner)))
      st = p.get('status') if isinstance(p,dict) else None
      if st not in ('received','uploading','uploaded','processing'):
        break
      time.sleep(2)

    # evidence summary and final status
    pr(f'summary {Path(path).name}', req('GET', f'/documents/{doc_id}/summary', headers=auth(owner)))
    pr(f'qa {Path(path).name}', req('POST', '/query', headers={**auth(owner),'Content-Type':'application/json'}, json={'query':'What is the policy number?','filters':{'document_id':doc_id},'request_id':None}))
    print(f"DOC_COMPLETE {Path(path).name} {doc_id}\n")

# cross-owner query fallback
# ensure token B no docs
owner_b = req('POST','/user/anonymous').json()['access_token']
pr('query root B empty', req('POST','/query', headers={**auth(owner_b),'Content-Type':'application/json'}, json={'query':'Any policy summary?','filters':{},'request_id':None}))

