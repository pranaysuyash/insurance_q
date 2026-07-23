# Test Assets Reference

Assets in `mobile/assets/test/` are used for manual and automated testing flows.

## Corrupt PDF — `assets/test/corrupt_test.pdf`

**Purpose:** Triggers the `ProcessingStatusScreen` retry flow during manual simulator
testing. The backend OCR/extraction pipeline cannot process this file, so it returns
`{status: "failed"}` from `GET /documents/{id}/status`, enabling the retry button.

**Properties:**
- Size: 1,000 bytes
- Content: random binary (`head -c 1000 /dev/urandom`)
- Identified as: `data` (not a valid PDF)

**Created by:** Session 2026-07-23's retry flow implementation
(`processing_status_retry_test.dart`).

### How to use

1. Launch the app on a simulator
2. Drag & drop `mobile/assets/test/corrupt_test.pdf` onto the simulator window
3. The upload will succeed (backend accepts the file), but processing will fail
4. `ProcessingStatusScreen` shows the error state with a **Retry** button
5. Tap Retry → `POST /documents/{id}/reprocess` → state resets to `received`
6. After 3 failed retries, the retry button is hidden and only "Back to documents" remains

### Using in test code

The 6 widget tests in `mobile/test/processing_status_retry_test.dart` verify this
flow programmatically without needing this file (they use a mock Dio interceptor).
This file is for **manual simulator testing** only.

### Server-side upload via curl

```bash
# Upload to local backend
TOKEN=$(curl -s -X POST localhost:8000/user/anonymous \
  -H 'Content-Type: application/json' | python3 -c \
  'import sys,json;print(json.load(sys.stdin).get("access_token",""))')

curl -X POST localhost:8000/documents/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "files=@mobile/assets/test/corrupt_test.pdf" \
  -F 'processing_mode=full'
```
