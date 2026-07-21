# CoverWise — Supabase Setup Runbook

**Purpose:** Step-by-step guide to configure Supabase for CoverWise auth, storage, and database.  
**Time estimate:** 30–45 minutes  
**Prerequisites:** Supabase project created, Google Cloud Console access (for Google Sign-In)  
**Reference:** `docs/UX_ISSUES_AUTH_AUDIT.md` §11  
**Last verified:** 2026-07-18 (code-level audit + §11I checklist)

### Verification Legend

| Symbol | Meaning |
|---|---|
| ✅ | Verified from code — no manual action needed |
| ❌ | Not configured — requires action |
| ⚠️ | Unknown — requires manual dashboard check |
| 🔲 | Not yet tested E2E |

---

## Step 1: Set Environment Variables (Build-Time) ❌ NOT CONFIGURED

**Verification status:** The `.env` file has no `SUPABASE_*` vars. `AppConfig.hasSupabaseAuthConfig` returns `false` at runtime. All auth features are disabled.

Add these to your build script or CI as `--dart-define` flags:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=eyJ... \
  --dart-define=API_BASE_URL=https://YOUR_API_URL
```

**How to find these values:**  
Supabase Dashboard → Settings → API → Project URL + anon/public key

**Verify:** Run the app. If you see "Account auth is not configured for this build," one of these is missing or empty.

---

## Step 2: Enable Email Provider ⚠️ NEEDS MANUAL CHECK

**Dashboard path:** Authentication → Providers → Email

**Verification status:** Cannot verify from code. Email is enabled by default in new Supabase projects, but must be confirmed in the dashboard.

1. Open the Providers list
2. Ensure **Email** is toggled ON (enabled by default in new projects)
3. Save if you changed anything

**Verify:** Try signing up with an email/password in the app. You should receive a confirmation email.

---

## Step 3: Add Redirect URLs ⚠️ NEEDS MANUAL CHECK

**Dashboard path:** Authentication → URL Configuration

**Verification status:** The `io.coverwise://` URL scheme is correctly registered in both iOS (`Info.plist`) and Android (`AndroidManifest.xml`). However, the redirect URLs must also be added in the Supabase dashboard — this cannot be verified from code.

Add these two redirect URLs to the **Redirect URLs** list:

| Redirect URL | Purpose | Code Reference |
|---|---|---|
| `io.coverwise://reset-callback` | Password reset — email link opens app to ResetPasswordScreen | `auth_service.dart:resetPassword()` |
| `io.coverwise://login-callback` | Google Sign-In — OAuth flow returns session via deep link | `auth_service.dart:signInWithGoogle()` |

**How to add:** Click "Add URL", paste each URL, click Save.

**⚠️ Without these:** Password reset emails show "Invalid link" and Google Sign-In fails silently.

**Verify:** After adding, the URLs should appear in the list with a green checkmark.

---

## Step 4: Create Storage Bucket ⚠️ NEEDS MANUAL CHECK

**Dashboard path:** Storage

**Verification status:** Backend code (`document_object_store.py`) defaults to `coverwise-documents` bucket. The bucket must exist in Supabase Storage — this cannot be verified from code.

1. Click **New bucket**
2. Name: `coverwise-documents`
3. Set to **Private** (NOT public — documents contain sensitive PII)
4. Click **Create bucket**

**Verify:** The bucket appears in the Storage list with "Private" badge.

---

## Step 5: Run Database Schema Migration ⚠️ NEEDS MANUAL CHECK

**Dashboard path:** SQL Editor

**Verification status:** The executable migration chain exists in
`supabase/migrations/` is the executable source. The `infra/supabase/` files
are retained historical SQL-editor snapshots, not a second migration source.
The migration SQL has been replayed against the local Postgres container; a
clean CLI reset/migration-history verification is still required before a
production push.

However, whether they've been applied to the Supabase project cannot be verified from code.

1. Prefer `supabase db push` from the repository root with the target project
   linked and reviewed migration status.
2. If the SQL Editor is required, apply the ordered files under
   `supabase/migrations/` in timestamp order and record the applied versions.
3. Do not apply both the timestamped chain and the `infra/supabase/` snapshots.

**Tables created by the base migration:**
- `documents` — Policy document metadata
- `document_chunks` — Chunked text for RAG embedding
- `analytics_events` — App analytics (Supabase is canonical in production)
- `dataset_releases`, `dataset_items` — consent-aware evaluation/training registry

**Verify:** Run `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';` — you should see all three tables.

---

## Step 6: Configure Google OAuth (Optional — P1) 🔲 NOT YET DONE

**Verification status:** Code is complete: `signInWithGoogle()` in `auth_service.dart`, Google button in `AccountScreen`, `google_sign_in: ^6.3.0` in `pubspec.yaml`. However, Supabase dashboard configuration is not done.

Only needed when you're ready to enable Google Sign-In.

### 6a. Register Android App in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials
2. Click **+ Create Credentials** → **Android app**
3. Fill in:
   - **Package name:** `com.example.coverwise` (verify in `mobile/android/app/build.gradle.kts` → `applicationId`)
   - **SHA-1 fingerprint (debug):** `96:0E:D9:BF:3A:9D:33:B5:8E:3F:83:01:EC:C6:C5:39:5E:9A:CC:1D`
   - **SHA-1 fingerprint (release):** `6B:5C:A6:45:BF:4B:E7:27:07:35:0B:86:78:CF:A9:0B:95:79:B7:03` (extracted from `upload-keystore.jks`, password: `android`, alias: `upload`)
4. Click **Register**

### 6b. Create Web Application OAuth Client ID

1. Google Cloud Console → APIs & Services → Credentials
2. Click **+ Create Credentials** → **OAuth client ID**
3. Application type: **Web application**
4. Name: `CoverWise Supabase Auth`
5. Authorized redirect URIs: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
6. Save **Client ID** and **Client Secret**

### 6c. Enable Google Provider in Supabase

1. Supabase Dashboard → Authentication → Providers → Google
2. Toggle **Enable**
3. Paste **Client ID** (from 6b)
4. Paste **Client Secret** (from 6b)
5. Click **Save**

**⚠️ Important:** Google Sign-In requires BOTH debug AND release SHA-1 fingerprints. Without the release fingerprint, Google Sign-In fails on production builds.

**Verify:** Tap the Google button in AccountScreen. You should see the Google OAuth consent screen.

---

## Step 7: Configure Email Templates (Optional)

**Dashboard path:** Authentication → Email Templates

The default templates work for most cases. Key templates:

| Template | What It Does | Customization Needed |
|---|---|---|
| **Confirm signup** | Sent after sign-up with confirmation link | None — default works |
| **Reset Password** | Sent when user taps "Forgot password?" | None — redirect is configured in code (`io.coverwise://reset-callback`) |
| **Change Email** | Sent when user changes email in account | None — default works |

**Verify:** Test password reset end-to-end (Step 9 below).

---

## Step 8: Set Backend Environment Variable ❌ NOT CONFIGURED

**Verification status:** Backend code (`user.py`, `document_repository.py`) expects `SUPABASE_SERVICE_ROLE_KEY` env var. The `.env` file has no Supabase vars. Account deletion and storage cleanup will fail without this.

Set `SUPABASE_SERVICE_ROLE_KEY` on your backend deployment (not in the mobile app):

```bash
# For local development, add to .env or export:
export SUPABASE_SERVICE_ROLE_KEY=eyJ...  # From Supabase Dashboard → Settings → API → service_role key
```

**⚠️ NEVER ship the service_role key in client apps.** It bypasses Row Level Security and has full admin access.

**Verify:** Account deletion endpoint (`DELETE /user/account`) should return 200 (not 401/403).

---

## Step 9: End-to-End Verification Checklist

**⚠️ BLOCKED:** Steps 1–8 must be completed before E2E testing. The app currently shows "Account auth is not configured for this build" because Supabase credentials are missing.

| # | Test | Expected Result | Status |
|---|---|---|---|
| 1 | Launch app, tap "Create account" | AccountScreen shows email/password form | 🔲 Blocked (no Supabase config) |
| 2 | Sign up with email/password | Confirmation email received | 🔲 Blocked |
| 3 | Tap confirmation link in email | App opens, user is signed in | 🔲 Blocked |
| 4 | Sign out, tap "Forgot password?" | Reset email received | 🔲 Blocked |
| 5 | Tap reset link in email | App opens to ResetPasswordScreen | 🔲 Blocked |
| 6 | Enter new password | Password updated, user signed in | 🔲 Blocked |
| 7 | Tap Google Sign-In button (if configured) | Google OAuth consent screen appears | 🔲 Blocked |
| 8 | Complete Google OAuth | User signed in with Google account | 🔲 Blocked |
| 9 | Upload a policy document | Document appears in Documents list | 🔲 Blocked |
| 10 | Go to Profile → Delete account | Two-step confirmation dialog appears | 🔲 Blocked |
| 11 | Confirm deletion (type "DELETE") | Account deleted, app returns to anonymous state | 🔲 Blocked |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| "Account auth is not configured" | Missing `--dart-define` env vars | Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` |
| Password reset link opens browser | `io.coverwise://reset-callback` not in redirect URLs | Add to Supabase → Auth → URL Configuration |
| Google Sign-In fails silently | Google provider not enabled or wrong Client ID | Complete Step 6 above |
| Email never arrives | Email provider disabled or quota exceeded | Enable Email in Auth → Providers, check Supabase billing |
| 403 on document upload | RLS policy missing or `owner_uid` mismatch | Verify RLS policies in Supabase → Database → Policies |
| Account deletion hangs | `SUPABASE_SERVICE_ROLE_KEY` not set on backend | Set env var on backend deployment |

---

*Last updated: 2026-07-18 — Verification findings from §11I audit added.*
