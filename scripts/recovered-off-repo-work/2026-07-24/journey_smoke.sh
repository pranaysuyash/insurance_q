#!/usr/bin/env bash
set -euo pipefail
source .venv/bin/activate
python - <<'PY'
from PIL import Image, ImageDraw
import uuid
img = Image.new('RGB', (612, 792), 'white')
d = ImageDraw.Draw(img)
stamp = uuid.uuid4().hex
d.text((50, 50), f'Journey final smoke {stamp}', fill='black')
img.save('/tmp/journey_unique_owner_a.pdf', format='PDF')
PY
TOK=$(curl -sS -X POST http://127.0.0.1:8008/user/anonymous -H 'Content-Type: application/json' -d '{"agree_to_privacy":true,"terms_version":"motto-v4"}')
AT=$(echo "$TOK" | jq -r '.access_token')
OWNER=$(echo "$TOK" | jq -r '.user.uid')
echo "OWNER=$OWNER"
RES=$(curl -sS -D - -o /tmp/upload_owner_a.json -H "Authorization: Bearer $AT" -F processing_consent=true -F processing_consent_version=motto-v4 -F 'files=@/tmp/journey_unique_owner_a.pdf;type=application/pdf' http://127.0.0.1:8008/documents/upload)
DOC_ID=$(jq -r '.documents[0].id // empty' /tmp/upload_owner_a.json)
echo "DOC_ID=$DOC_ID"
if [ -n "$DOC_ID" ]; then
  for i in $(seq 1 20); do
    ST_HTTP=$(curl -sS -H "Authorization: Bearer $AT" -o /tmp/doc_status_owner_a.json -w '%{http_code}' http://127.0.0.1:8008/documents/$DOC_ID/status)
    STATUS=$(jq -r '.status // empty' /tmp/doc_status_owner_a.json)
    STAGE=$(jq -r '.processing_details.stage // .processing_details.status // empty' /tmp/doc_status_owner_a.json)
    echo "i=$i http=$ST_HTTP status=$STATUS stage=$STAGE"
    if [ "$STATUS" = completed ] || [ "$STATUS" = failed ]; then
      break
    fi
    sleep 1
  done
  echo '--- summary ---'
  curl -sS -H "Authorization: Bearer $AT" http://127.0.0.1:8008/documents/$DOC_ID/summary || true
  echo
fi
