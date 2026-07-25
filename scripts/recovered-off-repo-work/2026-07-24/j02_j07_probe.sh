#!/usr/bin/env bash
set -euo pipefail

BASE='http://127.0.0.1:8010'
SAMPLE_PDF='/Users/pranay/Projects/medpiper/insurance_app/tests/test_data/sample_insurance.pdf'
SAMPLE_TXT='/Users/pranay/Projects/medpiper/insurance_app/storage/documents/sample_auto_policy.txt'

run() {
  local label="$1"
  shift
  local tmp
  tmp=$(mktemp)
  local code
  {
    code=$(eval "\$@ -w '\n%{http_code}'" >"$tmp")
  }
  echo "\n=== $label ==="
  local status=$(tail -n 1 "$tmp")
  local body=$(sed '$d' "$tmp" | head -c 8000)
  echo "STATUS: $status"
  if echo "$body" | jq . >/dev/null 2>&1; then
    echo "$body" | jq .
  else
    echo "$body"
  fi
  echo "$status" > /tmp/j02_last_status
  echo "$body" > /tmp/j02_last_body
  rm -f "$tmp"
}

# 1) anonymous
run "anon create" "curl -sS -X POST "$BASE"/user/anonymous"
OWNER_A=$(jq -r '.access_token' /tmp/j02_last_body)
if [ -z "$OWNER_A" ] || [ "$OWNER_A" = "null" ]; then
  echo "missing OWNER_A token"
  exit 1
fi

auth_h() { echo "Authorization: Bearer $1"; }

# consent current
run "consent current" "curl -sS -X GET '$BASE'/consent/current -H '$(auth_h "$OWNER_A")'"

# upload missing consent
run "upload missing consent" "curl -sS -X POST '$BASE'/documents/upload -H '$(auth_h "$OWNER_A")' -F 'processing_mode=full' -F 'files=@$SAMPLE_PDF'"

# upload invalid txt
run "upload txt invalid" "curl -sS -X POST '$BASE'/documents/upload -H '$(auth_h "$OWNER_A")' -F 'processing_consent=true' -F 'processing_consent_version=v4-test' -F 'files=@$SAMPLE_TXT;type=text/plain'"

# valid upload
run "upload valid" "curl -sS -X POST '$BASE'/documents/upload -H '$(auth_h "$OWNER_A")' -F 'processing_consent=true' -F 'processing_consent_version=v4-test' -F 'files=@$SAMPLE_PDF;type=application/pdf'"
DOC_ID=$(jq -r '.documents[0].id' /tmp/j02_last_body)
echo "DOC_ID=$DOC_ID"

# replay
run "upload idempotent replay" "curl -sS -X POST '$BASE'/documents/upload -H '$(auth_h "$OWNER_A")' -F 'processing_consent=true' -F 'processing_consent_version=v4-test' -F 'files=@$SAMPLE_PDF;type=application/pdf'"

# list docs
run "documents list owner" "curl -sS -X GET '$BASE'/documents -H '$(auth_h "$OWNER_A")'"

# status polls
for i in {1..12}; do
  run "status poll $i" "curl -sS -X GET '$BASE'/documents/$DOC_ID/status -H '$(auth_h "$OWNER_A")'"
  st=$(jq -r '.status // empty' /tmp/j02_last_body)
  if [ -z "$st" ] || [ "$st" = "null" ]; then
    st=$(cat /tmp/j02_last_body)
  fi
  echo "poll_status=$st"
  if [ "$st" != "received" ] && [ "$st" != "processing" ] && [ "$st" != "uploaded" ] && [ "$st" != "null" ]; then
    break
  fi
  sleep 2
  done

# evidence & summary
run "summary" "curl -sS -X GET '$BASE'/documents/$DOC_ID/summary -H '$(auth_h "$OWNER_A")'"
run "evidence field citations" "curl -sS -X GET '$BASE'/evidence/$DOC_ID/field-citations -H '$(auth_h "$OWNER_A")'"

# query root
run "query root" "curl -sS -X POST '$BASE'/query -H '$(auth_h "$OWNER_A")' -H 'Content-Type: application/json' -d '{\"query\":\"What is this document about?\",\"filters\":{},\"request_id\":null}'"
# documents/query deprecated
run "query documents/query" "curl -sS -X POST '$BASE'/documents/query -H '$(auth_h "$OWNER_A")' -F 'query=What is this document about?' -F "document_ids=$DOC_ID""

# cross-owner isolation
run "anon create B" "curl -sS -X POST '$BASE'/user/anonymous"
OWNER_B=$(jq -r '.access_token' /tmp/j02_last_body)
if [ -z "$OWNER_B" ] || [ "$OWNER_B" = "null" ]; then
  echo "missing OWNER_B token"
else
  run "cross-owner list B" "curl -sS -X GET '$BASE'/documents -H '$(auth_h "$OWNER_B")'"
  run "cross-owner doc status B" "curl -sS -X GET '$BASE'/documents/$DOC_ID/status -H '$(auth_h "$OWNER_B")'"
  run "claim-anonymous as anon" "curl -sS -X POST '$BASE'/user/claim-anonymous -H '$(auth_h "$OWNER_B")' -H 'Content-Type: application/json' -d '{\"anonymous_token\":\"'$OWNER_A'\"}'"
fi

run "health" "curl -sS -X GET '$BASE'/health"

