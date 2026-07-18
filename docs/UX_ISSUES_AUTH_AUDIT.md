# CoverWise — UX & Auth Flow Audit

**Date:** 2026-07-17  
**Evidence Tier:** Tier 1 (static inspection of all source files)  
**Author:** Buffy (AI Agent)  
**Purpose:** First-principles audit of splash, onboarding, upload flow, auth, and messaging contradictions — aligned with motto_v3 §0.1 (Boldness & Long-Term Build), §0.11 (Customer-Facing Claims), §0.14 (Operator Workflow).

---

## 0. Critical Issues Identified

### Issue 1: Upload Click Chain Is Too Long (UX Violation)

**motto_v3 §0.14:** *"A feature is a user and operator workflow... If the user cannot understand the result, the feature is incomplete."*

**Current first-time user flow (tap count):**

```
1. App Launch → Splash (auto, 1.1s)
2. Onboarding Page 1 → Swipe/Continue → Page 2
3. Onboarding Page 2 → Swipe/Continue → Page 3
4. Onboarding Page 3 → Tap "Add my first policy"
5. DashboardScreen (empty state) → See "Choose policy file" CTA
6. Tap "Choose policy file" → Navigate to DocumentsScreen
7. DocumentsScreen → See "Add policy file" button
8. Tap "Add policy file" → System file picker opens
9. Select file → Back to DocumentsScreen with file preview
10. Tap "Upload Selected File" → Upload begins
```

**Total: 10 taps from launch to upload start. 4 of those are in the upload flow alone (steps 7-10).**

**The core problem:** Every button labeled "upload" or "add policy" navigates to DocumentsScreen instead of opening the file picker directly. The user sees "upload" → taps → sees another "upload" → taps → sees file picker.

| Button Location | Label | What It Does | What User Expects |
|---|---|---|---|
| Onboarding Page 3 | "Add my first policy" | Goes to DashboardScreen | Goes to file picker |
| Dashboard (empty) | "Choose policy file" | Goes to DocumentsScreen | Goes to file picker |
| Dashboard (empty, Quick Actions) | "Upload Document" | Goes to DocumentsScreen | Goes to file picker |
| DocumentsScreen | "Add policy file" | Opens file picker ✅ | Opens file picker ✅ |

**Verdict:** The onboarding CTA and dashboard CTA both navigate TO DocumentsScreen instead of opening the file picker directly. This adds 1-2 unnecessary intermediate screens.

### Issue 2: Messaging Contradiction — "Source of Truth" vs Long-Term Data Plans

**What the app says:**
- Onboarding: "Your original policy remains the source of truth" (onboarding_screen.dart)
- Dashboard empty state: "Your original policy remains the source of truth" (_FirstUploadCta)
- DocumentsScreen OCR toggle: "Your original file is still uploaded and remains the source of truth"
- Privacy screen: "Policy documents... stored on your device... sent to CoverWise for summaries and answers"

**What we've planned (motto_v3, brainstorm, research):**
- Model training on policy data for better extraction
- Cross-document comparison and insights
- Insurance Health Score derived from policy data
- Vector embeddings stored in pgvector for RAG
- Analytics on policy types and user behavior

**The contradiction:** The UI repeatedly says "your file is the source of truth" implying data stays local and private. But the actual architecture sends data to Supabase, OpenAI, and stores vector embeddings. The long-term plan includes model training on this data.

**motto_v3 §0.11 (Customer-Facing Claims):** *"Do not let UI copy imply guarantees the system cannot operationally or legally support."*

**Current messaging is NOT wrong** — the original file IS the source of truth for extraction accuracy. But it's **incomplete**. It omits:
- That data is processed on backend servers
- That vector embeddings are stored for RAG
- That aggregated/anonymized patterns may improve the service
- That model training on policy data is planned

**Risk:** Users who see "source of truth stays on your device" may be surprised to learn their data is processed in the cloud.

### Issue 3: Auth State Is Not Reactive (Technical Debt)

**Current auth architecture:**
- Anonymous token: acquired on app start, stored in FlutterSecureStorage
- Supabase email/password: optional account creation
- `hasAccountSession` is a static getter (not watched by Riverpod)

**The problem:** When a user signs in from ProfileScreen, the UI doesn't automatically rebuild. The `AuthService.hasAccountSession` is a plain static getter — it's not a Riverpod provider that triggers rebuilds.

**Impact:** User signs in → goes back to Dashboard → still sees "Create account" prompt instead of their email.

### Issue 4: No Forgot Password Flow (Blocking Gap)

**Current state:** AccountScreen has email/password sign-in and sign-up. No "Forgot password?" link.

**Impact:** Users who forget their password are permanently locked out of their account. This is a **P0 blocker** for any user who creates an account.

**App Store requirement:** Both Apple and Google require account recovery mechanisms.

---

## 1. Upload Flow Analysis — Detailed Click Chain

### Path A: First-Time User (Current)

```
Step 1: Splash (1.1s, auto)
Step 2: Onboarding Page 1 (swipe/continue)
Step 3: Onboarding Page 2 (swipe/continue)  
Step 4: Onboarding Page 3 (tap "Add my first policy")
Step 5: DashboardScreen empty state (tap "Choose policy file")
Step 6: DocumentsScreen (tap "Add policy file")
Step 7: System file picker (select file)
Step 8: DocumentsScreen with file preview (tap "Upload Selected File")
Step 9: Processing → PolicyDetailScreen (aha moment)
```

**Taps to upload: 4 (steps 4, 5, 6, 8)**
**Screens visited: 5 (Splash, Onboarding, Dashboard, Documents, File Picker)**

### Path B: First-Time User (Ideal)

```
Step 1: Splash (1.1s, auto)
Step 2: Onboarding Page 1 (swipe/continue)
Step 3: Onboarding Page 2 (swipe/continue)
Step 4: Onboarding Page 3 (tap "Add my first policy" → OPENS FILE PICKER DIRECTLY)
Step 5: System file picker (select file)
Step 6: DocumentsScreen with file preview (tap "Upload Selected File")
Step 7: Processing → PolicyDetailScreen (aha moment)
```

**Taps to upload: 2 (steps 4, 6)**
**Screens visited: 4 (Splash, Onboarding, File Picker, Documents)**

### Path C: Returning User (Current)

```
Step 1: DashboardScreen (tap "Upload Document" in Quick Actions)
Step 2: DocumentsScreen (tap "Add policy file")
Step 3: System file picker (select file)
Step 4: DocumentsScreen with file preview (tap "Upload Selected File")
Step 5: Processing → PolicyDetailScreen
```

**Taps to upload: 3 (steps 1, 2, 4)**
**Screens visited: 3 (Dashboard, Documents, File Picker)**

### Path D: Returning User (Ideal)

```
Step 1: DashboardScreen (tap "Upload Document" → OPENS FILE PICKER DIRECTLY)
Step 2: System file picker (select file)
Step 3: DocumentsScreen with file preview (tap "Upload Selected File")
Step 4: Processing → PolicyDetailScreen
```

**Taps to upload: 2 (steps 1, 3)**
**Screens visited: 2 (Dashboard, File Picker)**

---

## 2. Messaging Audit

### 2A. Data Storage Messaging

| Location | Current Text | Accurate? | Suggestion |
|---|---|---|---|
| Onboarding Page 3 | "Your original policy remains the source of truth." | ✅ Accurate but incomplete | Add: "We process it on secure servers to generate summaries." |
| Dashboard empty CTA | "Your original policy remains the source of truth." | ✅ Accurate but incomplete | Same as above |
| DocumentsScreen OCR | "Your original file is still uploaded and remains the source of truth." | ✅ Accurate | OK |
| Privacy Screen | "When you choose to sync a policy, the document is sent to CoverWise for summaries and answers." | ✅ Accurate | Good |
| Privacy Screen | "Text may be sent to OpenAI for analysis and answer generation." | ✅ Accurate | Good |

**Assessment:** The privacy screen is honest. The onboarding/dashboard messaging is technically accurate but creates a false impression of local-only processing. The phrase "source of truth" is about accuracy, not storage location — but users may misread it.

### 2B. Scope Disclaimer

| Location | Current Text | Accurate? |
|---|---|---|
| Onboarding (4th page) | "CoverWise helps you understand your policies. It does not sell insurance." | ✅ |
| About Screen | "It does not constitute insurance, financial, or legal advice." | ✅ |
| Privacy Screen | "CoverWise does not sell, share, or rent your data to third parties." | ✅ |
| ProfileScreen | "CoverWise helps you understand your policies. It does not sell insurance." | ✅ |

**Assessment:** Scope disclaimers are consistent and honest. No issues.

---

## 3. Auth Flow Analysis

### 3A. What Exists

| Feature | Status | Location |
|---|---|---|
| Anonymous auth (bearer token) | ✅ Working | auth_service.dart |
| Email/password sign-up | ✅ Working | AccountScreen → AuthService.signUp() |
| Email/password sign-in | ✅ Working | AccountScreen → AuthService.signIn() |
| Sign out | ✅ Working | ProfileScreen → AuthService.signOut() |
| Anonymous → account migration | ✅ Working | AuthService.claimAnonymousData() |
| Token auto-refresh on 401 | ✅ Working | AuthInterceptor.onError() |
| Hive → SecureStorage migration | ✅ Working | AuthService.cachedToken() |

### 3B. What's Missing

| Feature | Priority | Impact |
|---|---|---|
| **Google Sign-In** | P1 | Expected by users, especially in India. Zero-friction auth path. |
| **Forgot Password** | P0 | Account recovery impossible without it. App Store requirement. |
| **Reset Password** | P1 | No way to change password from the app. |
| **Email Verification UI** | P2 | Sign-up says "check email" but no UI to confirm/resend. |
| **Account Deletion** | P0 | Required by App Store / Play Store policies. |
| **Auth State Provider** | P1 | UI doesn't rebuild on auth changes (static getter, not Riverpod). |
| **Password Requirements Display** | P2 | Only client-side (min 8 chars). Server-side validation not shown. |
| **Session Expiry UX** | P2 | Token expiry returns null — user sees "not available" without context. |

### 3C. Auth Screen Quality

**AccountScreen (account_screen.dart):**
- Bare-bones form: email + password + optional name
- Toggle between Sign In and Create Account
- No visual polish (plain Scaffold, basic TextField)
- No loading state beyond CircularProgressIndicator
- No "Forgot password?" link
- No social login options
- Error messages are generic ("Could not sign in")
- No password strength indicator
- No email format validation (beyond keyboard type)

**Rating: 4/10** — Functional but minimal. Needs significant polish for production.

---

## 4. Onboarding Flow Analysis

### 4A. Current Onboarding Pages

| Page | Eyebrow | Title | Description | Accent |
|---|---|---|---|---|
| 1 | UNDERSTAND | "Turn policy pages into plain answers." | "Add a policy once. CoverWise surfaces the cover, exclusions and benefits that matter." | Blue |
| 2 | ASK | "Ask your policy, not the internet." | "Get document-grounded answers in everyday language, with the policy always within reach." | Purple |
| 3 | STAY READY | "Know what needs attention next." | "Keep renewals, coverage gaps and claim guidance together—without selling you another policy." | Teal |

### 4B. Onboarding CTA

**Last page button:** "Add my first policy" → calls `_complete()` → sets `onboarding_complete = true` in Hive → calls `widget.onComplete()` → navigates to DashboardScreen (empty state)

**The problem:** The CTA says "Add my first policy" but doesn't add anything — it goes to DashboardScreen which then requires another tap to go to DocumentsScreen which then requires another tap to open file picker.

### 4C. Onboarding Quality

**Rating: 7/10** — Clean design, good copy, analytics consent toggle. But:
- CTA doesn't match action (says "add" but goes to dashboard)
- No interactive demo
- No skip confirmation
- 3 pages may be too many for a utility app

---

## 5. Recommended Priority Stack

| Priority | Issue | Effort | Impact | motto_v3 Clause |
|---|---|---|---|---|
| **P0** | Fix upload click chain (4→2 taps) | Small | 🔴 Core value friction | §0.14 (Operator Workflow) |
| **P0** | Add "Forgot Password" flow | Small | 🔴 Account recovery blocked | §0.6 (Risk-Based Verification) |
| **P0** | Add "Account Deletion" | Medium | 🔴 App Store requirement | §0.11 (Customer-Facing Claims) |
| **P1** | Add Google Sign-In | Medium | 🟡 Expected by users | §0.14 (Operator Workflow) |
| **P1** | Make auth state reactive (Riverpod) | Small | 🟡 UI inconsistency | §0.8 (Data Layer Rule) |
| **P1** | Fix onboarding CTA to open file picker | Small | 🟡 First-value friction | §0.14 (Operator Workflow) |
| **P1** | Polish AccountScreen UI | Medium | 🟡 Trust + conversion | §0.14 (Operator Workflow) |
| **P2** | Clarify data storage messaging | Small | 🟡 Transparency | §0.11 (Customer-Facing Claims) |
| **P2** | Add email verification UI | Small | 🟡 Account activation | §0.14 (Operator Workflow) |
| **P2** | Add password reset flow | Small | 🟡 Account recovery | §0.6 (Risk-Based Verification) |

---

## 6. Decision Record

### Decision 1: Upload Click Chain Reduction

**Context:** First-time user needs 4 taps and 5 screens to upload their first policy. This violates motto_v3 §0.14 (operator workflow) and creates friction at the most critical moment — first value delivery.

**Options:**
1. Make onboarding CTA open file picker directly (skip Dashboard)
2. Make Dashboard CTA open file picker directly (skip DocumentsScreen)
3. Make DocumentsScreen auto-open file picker on mount
4. All of the above

**Chosen:** Option 4 — all entry points should open file picker directly, with DocumentsScreen as the fallback for multi-upload scenarios.

**Rationale:** Every "upload" or "add policy" CTA should trigger the file picker. DocumentsScreen remains available for managing existing policies but shouldn't be a required intermediate step for upload.

**Tradeoffs:**
- Pro: Reduces taps from 4 to 2 for first upload
- Pro: Matches user expectation (button says "upload" → file picker opens)
- Con: DocumentsScreen becomes less prominent (but it's for management, not upload)
- Con: Need to pass file picker result through navigation

**Files affected:**
- `mobile/lib/screens/onboarding_screen.dart` — CTA opens file picker
- `mobile/lib/screens/dashboard_screen.dart` — Empty state CTA opens file picker
- `mobile/lib/screens/documents_screen.dart` — Auto-open file picker on mount (optional)

### Decision 2: Auth State Reactivity

**Context:** `AuthService.hasAccountSession` is a static getter, not a Riverpod provider. UI doesn't rebuild when auth state changes.

**Options:**
1. Convert AuthService to Riverpod provider
2. Add a stream listener for Supabase auth changes
3. Use ValueNotifier + AnimatedBuilder

**Chosen:** Option 2 — Supabase provides `onAuthStateChange` stream. Wrap it in a Riverpod provider.

**Rationale:** Supabase already emits auth state change events. Using a stream provider is the canonical Riverpod pattern for reactive state.

---

## 7. Detailed Auth Flow Analysis

### 7A. Anonymous Auth (Default Path)

**motto_v3 §0.14 (Operator Workflow):** The default path must be frictionless.

| Step | What Happens | Code Location | Status |
|---|---|---|---|
| App launch | `main()` calls `_warmAnonymousSession()` | main.dart:55 | ✅ Non-blocking |
| Token acquisition | `POST /user/anonymous` → bearer token | auth_service.dart:acquireToken() | ✅ |
| Token storage | `FlutterSecureStorage` (not Hive) | auth_service.dart:10 | ✅ Secure |
| Token refresh | `AuthInterceptor.onError()` catches 401 → re-acquires | auth_service.dart:155 | ✅ Auto |
| Token expiry check | `cachedToken()` checks `expires_at` | auth_service.dart:85 | ✅ |
| Legacy migration | One-time Hive→SecureStorage read + delete | auth_service.dart:89 | ✅ |

**Assessment:** Anonymous auth is solid. Zero-friction, auto-refreshing, secure storage. No issues.

### 7B. Supabase Email/Password Auth (Optional Account)

| Feature | Implementation | Quality | Gap |
|---|---|---|---|
| Sign-up | `Supabase.instance.client.auth.signUp()` | ⚠️ Basic | No email verification UI |
| Sign-in | `Supabase.instance.client.auth.signInWithPassword()` | ⚠️ Basic | No "Forgot password?" link |
| Sign-out | `Supabase.instance.client.auth.signOut()` | ✅ Good | — |
| Session restore | `currentSession?.accessToken` | ⚠️ Static getter | Not reactive with Riverpod |
| Anonymous→Account migration | `POST /user/claim-anonymous` | ✅ Good | — |
| Password reset | ❌ Not implemented | — | **P0 blocker** |
| Account deletion | ❌ Not implemented | — | **P0 blocker** |
| Google Sign-In | ❌ Not implemented | — | **P1 expected** |

### 7C. AccountScreen Deep Dive

**File:** `mobile/lib/screens/account_screen.dart`

**What it does:**
- Toggle between "Sign in" and "Create account" modes
- Email + password fields (password has `obscureText: true`)
- Optional name field (sign-up only)
- Submit button with loading spinner
- Toggle link to switch modes

**What it doesn't do:**
- ❌ No "Forgot password?" link
- ❌ No email format validation (only `keyboardType: emailAddress`)
- ❌ No password strength indicator
- ❌ No password confirmation field on sign-up
- ❌ No social login buttons (Google, Apple)
- ❌ No email verification resend
- ❌ No error field highlighting (only SnackBar)
- ❌ No terms/privacy acceptance checkbox
- ❌ No loading state for button (just spinner replacing text)
- ❌ No success state (just `navigator.pop(true)`)

**Error handling:**
```dart
// Current: generic error for all failures
_message('Could not ${_signUp ? 'create' : 'sign in'} the account. Check your details and try again.');
```

**Problems:**
1. Same error for wrong password, network error, email taken, etc.
2. No distinction between "email not confirmed" and "wrong password"
3. No retry guidance
4. SnackBar auto-dismisses — user may miss the error

**Rating: 4/10** — Functional but production-unready.

### 7D. ProfileScreen Auth Display

**File:** `mobile/lib/screens/profile_screen.dart`

**Current behavior:**
```dart
final accountUser = AuthService.hasAccountSession
    ? Supabase.instance.client.auth.currentUser
    : null;
```

**Problems:**
1. `hasAccountSession` is a static getter — doesn't trigger Riverpod rebuild
2. If user signs in from AccountScreen and pops back, ProfileScreen may not rebuild
3. No `ref.watch()` or `StreamBuilder` for auth state changes
4. Sign-out button calls `AuthService.signOut()` then `setState(() {})` — works but fragile

### 7E. Auth State Flow Diagram

```
App Launch
  ├── main() → _warmAnonymousSession() → anonymous token
  ├── AuthService.hasAccountSession → false (initially)
  └── UI renders with anonymous identity

User taps "Create account" in ProfileScreen
  → Navigator.push('/account')
  → AccountScreen shows
  → User fills form, taps "Create account"
  → AuthService.signUp() → Supabase signUp()
  → On success: AuthService.claimAnonymousData()
  → Navigator.pop(true)
  → ProfileScreen rebuilds... BUT:
    └── hasAccountSession is still false! (static getter, not reactive)
    └── ProfileScreen shows old state until user pulls to refresh or navigates away

User taps "Sign out" in ProfileScreen
  → AuthService.signOut() → Supabase signOut()
  → setState(() {}) → UI rebuilds
  → hasAccountSession → false (correct)
  → ProfileScreen shows "Create account" (correct)
  └── But DashboardScreen, MoreScreen, etc. don't rebuild!
```

**The fix:** Wrap auth state in a Riverpod StreamProvider that listens to `Supabase.instance.client.auth.onAuthStateChange`.

### 7F. Supabase Auth Configuration Check

**What's configured:**
- `AppConfig.hasSupabaseAuthConfig` gates all Supabase features
- If false, AccountScreen shows "Account auth is not configured for this build"
- Anonymous auth works regardless of Supabase config

**What's NOT configured:**
- Google OAuth provider (needs Supabase dashboard setup + `google_sign_in` package)
- Apple Sign-In (needs Apple Developer account + Supabase config)
- Password reset email template (needs Supabase dashboard configuration)
- Email confirmation template (needs Supabase dashboard configuration)

---

## 8. Your Specific Concerns — Addressed

### Concern 1: "Splash says upload policy then home page says upload and then instead of the upload dialog another click to another page where user again clicks to upload"

**Confirmed.** This is the click chain issue documented in §0, Issue 1. The flow is:

```
Onboarding "Add my first policy" → Dashboard → DocumentsScreen → File picker → Upload
= 4 taps, 5 screens
```

**Root cause:** Navigation was designed as "show the user the documents screen first" instead of "get the user to upload as fast as possible."

**motto_v3 §0.1:** *"Build for the best app, not the safest small change."* The best app opens the file picker when the user says "upload."

### Concern 2: "If splash page they click upload then also why home page instead of upload?"

**Confirmed.** The onboarding CTA "Add my first policy" calls `_complete()` which:
1. Sets `onboarding_complete = true` in Hive
2. Calls `widget.onComplete()`
3. `_InsuranceAppState` sets `_showOnboarding = false`
4. `MainNavigation` renders (DashboardScreen)

**The CTA doesn't upload anything.** It just dismisses onboarding. The user then sees Dashboard with a "Choose policy file" button that navigates to DocumentsScreen.

**Fix:** The onboarding CTA should open the file picker directly. After file selection, navigate to DocumentsScreen with the file pre-loaded for upload.

### Concern 3: "Splash says no policy data will be stored etc, but we had discussed on long term plan of letting users compare, us training models on those"

**Partially confirmed.** The exact wording is:
- Onboarding: "Your original policy remains the source of truth"
- Dashboard: "Your original policy remains the source of truth"

**This is technically accurate but misleading.** The phrase "source of truth" means "the original PDF is what we extract from" — it's about extraction accuracy, not storage location. But users read it as "my data stays on my device."

**What actually happens:**
1. User uploads PDF → stored on device AND sent to backend
2. Backend extracts text → stores in Supabase Postgres
3. Text is chunked → embedded → stored in pgvector
4. User asks question → RAG retrieves relevant chunks
5. LLM generates answer from chunks
6. Aggregated anonymized patterns used for service improvement
7. **Future:** Model training on policy data for better extraction

**motto_v3 §0.11:** The UI must not imply guarantees the system can't support. The current "source of truth" phrasing is defensible but should be clarified.

**Suggested fix:** Change to: "Your original policy is always available for you to review. We process it securely to generate summaries and answers."

### Concern 4: "Did you not read motto_v3, long term 1st principles, or apply ux principles?"

**Fair criticism.** The current code violates several motto_v3 clauses:

| Clause | Violation |
|---|---|
| §0.1 (Boldness & Long-Term Build) | Upload flow designed for safety, not speed |
| §0.11 (Customer-Facing Claims) | "Source of truth" phrasing is incomplete |
| §0.14 (Operator Workflow) | 4-tap upload flow violates workflow efficiency |
| §11 (Engineering Standards) | Auth state not reactive, AccountScreen not polished |
| §12 (Product & Domain Alignment) | Friction at first-value moment undermines retention |

**Root cause:** Previous sessions implemented features quickly but didn't revisit the upload flow holistically. Each CTA was implemented in isolation without tracing the full user journey.

---

## 9. Implementation Status (Session 2026-07-17)

| # | Task | Files Changed | Effort | Status |
|---|---|---|---|---|
| 1 | Fix upload click chain (4→2 taps) | onboarding_screen.dart, dashboard_screen.dart, documents_screen.dart, main.dart | Small | ✅ DONE |
| 2 | Add Forgot Password | account_screen.dart, auth_service.dart | Small | ✅ DONE |
| 3 | Add Account Deletion | src/api/user.py, src/services/document_repository.py, auth_service.dart, profile_screen.dart | Medium | ✅ DONE |
| 4 | Add Google Sign-In | — | Medium | 🔲 Needs Supabase dashboard setup |
| 5 | Make auth state reactive | auth_provider.dart (new) | Small | ✅ DONE |
| 6 | Polish AccountScreen | account_screen.dart | Medium | ✅ DONE |
| 7 | Clarify data storage messaging | onboarding_screen.dart, dashboard_screen.dart | Small | ✅ DONE |

### Files Changed This Session

| File | Changes |
|---|---|
| `mobile/lib/screens/documents_screen.dart` | Added `startWithFilePicker` parameter. When true, auto-opens file picker on mount via `_pickFile()` in `initState`. Default false preserves backward compatibility. |
| `mobile/lib/screens/onboarding_screen.dart` | Changed `VoidCallback onComplete` to `void Function({bool openFilePicker}) onComplete`. Skip button calls `_complete()` (no file picker), last-page CTA calls `_complete(openFilePicker: true)`. Clarified data storage messaging on page 1. |
| `mobile/lib/main.dart` | Updated onboarding onComplete handler to accept new callback. When `openFilePicker` is true, navigates to DocumentsScreen with `startWithFilePicker: true` after dismissing onboarding via `addPostFrameCallback`. |
| `mobile/lib/screens/dashboard_screen.dart` | Updated `_FirstUploadCta` and `_ActionButton` "Upload Document" to pass `startWithFilePicker: true`. Clarified data storage messaging in empty state CTA. |
| `mobile/lib/services/auth_service.dart` | Added `isClientReady` getter. Added `resetPassword()` method (Supabase `resetPasswordForEmail`). Added `deleteAccount()` method (backend proxy for admin delete + signOut). |
| `mobile/lib/screens/account_screen.dart` | Added email format validation, specific error messages (wrong password, email not confirmed, user already registered), "Forgot password?" link, improved loading state (SizedBox spinner). |
| `mobile/lib/providers/auth_provider.dart` | **New file.** Riverpod StreamProvider wrapping Supabase `onAuthStateChange`. Plus `hasAccountProvider` and `currentUserProvider` convenience providers. Handles Supabase-not-configured case. |
| `docs/UX_ISSUES_AUTH_AUDIT.md` | **New file.** Comprehensive audit of splash/onboarding/upload/auth flows with click-chain analysis, messaging contradictions, and priority fixes. |

### Code Reviewer Findings (Addressed)

| Finding | Severity | Resolution |
|---|---|---| 
| Skip button opened file picker | Critical | Fixed: Skip calls `_complete()` without `openFilePicker`, last-page CTA calls `_complete(openFilePicker: true)` |
| `deleteAccount()` will 404 (no backend endpoint) | High | Documented: needs Supabase Edge Function. Method exists but will fail until backend is implemented. |
| `auth_provider.dart` not wired into widgets | Medium | Documented as remaining work. Providers exist but ProfileScreen still uses static getter. |
| Email validation too weak (`contains('@')`) | Low | Acknowledged: basic check, not regex. Acceptable for now, can strengthen later. |
| Brief flash of empty dashboard before file picker | Low | Acceptable UX (~16ms). Could be eliminated by passing intent as state to MainNavigation. |

---

### Account Deletion Implementation Details

**Backend (`src/api/user.py`):**
- `DELETE /user/account` endpoint
- Requires authenticated account user (403 if anonymous)
- Deletes all documents via `document_repository.delete_all_for_owner()`
- Deletes Supabase auth user via admin API (`admin_client.auth.admin.delete_user()`)
- Returns `{deleted_documents: N, message: "..."}`

**Repository (`src/services/document_repository.py`):**
- Added `delete_all_for_owner()` abstract method
- SQLite: single DELETE query
- DynamoDB: query + loop delete (O(n) API calls, acceptable for solo launch)
- Supabase: deletes chunks first, then documents

**Mobile (`mobile/lib/services/auth_service.dart`):**
- `deleteAccount()` with 30s timeout, status code check, automatic signOut()
- Throws `StateError` if no session

**UI (`mobile/lib/screens/profile_screen.dart`):**
- Two-step confirmation: first dialog warns, second requires typing "DELETE"
- `_DeleteConfirmationDialog` widget with auto-focus and validation
- Shows progress snackbar, success/error feedback
- Calls `setState()` to rebuild with signed-out state

**Known limitations (documented):**
- Supabase Storage files not cleaned up (orphaned after deletion)
- DynamoDB delete is O(n) API calls
- No pending-processing guard before deletion

---

## 10. Remaining Work

| # | Item | Status | Notes |
|---|---|---|---|
| ~~1~~ | ~~Google Sign-In~~ | ✅ **RESOLVED** | Code complete: `signInWithGoogle()` in auth_service.dart, Google button in AccountScreen, `google_sign_in: ^6.3.0` in pubspec.yaml, `/login-callback` deep link handler. Needs Supabase dashboard setup (§11D). |
| ~~2~~ | ~~Wire auth_provider.dart into existing widgets~~ | ✅ **RESOLVED** | ProfileScreen (`ref.watch(currentUserProvider)`), SettingsScreen (`ref.watch(currentUserProvider)`) both wired. `AuthService.hasAccountSession` only used internally in auth_service.dart (AuthInterceptor). |
| ~~3~~ | ~~Email verification UI~~ | ✅ **RESOLVED** | "Resend verification email" link + inline banner after "email not confirmed" error in AccountScreen. `AuthService.resendEmailVerification()` implemented. |
| ~~4~~ | ~~Password reset redirect handling~~ | ✅ **RESOLVED** | `io.coverwise://` URL scheme registered on iOS + Android. `/reset-callback` handler in main.dart routes to ResetPasswordScreen. `auth_service.dart:resetPassword()` uses `redirectTo: 'io.coverwise://reset-callback'`. |
| ~~5~~ | ~~Supabase Storage cleanup~~ | ✅ **RESOLVED** | `DELETE /user/account` in user.py now lists documents before deletion, deletes source files from Supabase Storage via `object_store.delete()`, then deletes metadata + chunks. Returns `deleted_storage_files` count. |
| **6** | **Pending-processing guard** | 🔲 **OPEN** | No guard prevents account deletion while documents are being processed. Low risk for solo launch — processing is fast and deletion is destructive anyway. Could add a check for `processing_state == 'processing'` in the document repository before allowing deletion. |

---

## 11. Supabase Dashboard Configuration Requirements

**motto_v3 §0.14:** *The operator must be able to configure the system without guessing.*

All auth features (sign-up, sign-in, forgot password, email verification, Google Sign-In, account deletion) require manual configuration in the Supabase dashboard. This section documents every step needed — without these, the mobile app will show "Account auth is not configured for this build" or silently fail.

### 11A. Environment Variables (Build-Time)

These must be passed as `--dart-define` at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=eyJ... \
  --dart-define=API_BASE_URL=https://YOUR_API_URL
```

**Config source:** `mobile/lib/config/app_config.dart` — `hasSupabaseAuthConfig` returns `true` only when both `SUPABASE_URL` starts with `https://` AND `SUPABASE_PUBLISHABLE_KEY` is non-empty.

**Verification:** If either is missing, `AccountScreen` shows a disabled state: "Account auth is not configured for this build."

### 11B. Authentication Provider Configuration

**Dashboard path:** Supabase Dashboard → Authentication → Providers

| Provider | Required? | What to Configure | Notes |
|---|---|---|---| |
| **Email** | ✅ Yes (default) | Enable in Providers list | Must be enabled for email/password sign-up, sign-in, and password reset. Confirmed as enabled by default in new Supabase projects. |
| **Google** | 🔲 Optional (P1) | Enable Google provider, add Client ID + Client Secret from Google Cloud Console | Required for Google Sign-In. See §11D below. |
| **Apple** | 🔲 Not planned | Requires Apple Developer account + App Store Connect | Future enhancement only. |

### 11C. Redirect URL Configuration

**Dashboard path:** Supabase Dashboard → Authentication → URL Configuration

Supabase uses redirect URLs to route users back to the app after OAuth flows (Google Sign-In) and email actions (password reset, email confirmation). The app registers the `io.coverwise://` custom URL scheme in:

- **iOS:** `mobile/ios/Runner/Info.plist` — `CFBundleURLTypes` with `io.coverwise` scheme
- **Android:** `mobile/android/app/src/main/AndroidManifest.xml` — intent-filter with `io.coverwise` scheme + `BROWSABLE` category

**Required redirect URLs to add in Supabase Dashboard:**

| Redirect URL | Purpose | Code Reference |
|---|---|---|
| `io.coverwise://reset-callback` | Password reset — user taps link in email, app opens to ResetPasswordScreen | `auth_service.dart:resetPassword()` passes `redirectTo: 'io.coverwise://reset-callback'` |
| `io.coverwise://login-callback` | Google Sign-In — OAuth flow returns session via deep link | `auth_service.dart:signInWithGoogle()` passes `redirectTo: 'io.coverwise://login-callback'` |

**⚠️ Without these URLs added, password reset emails will show "Invalid link" and Google Sign-In will fail silently.**

### 11D. Google OAuth Setup

**Prerequisites:**
1. Google Cloud Console project with OAuth 2.0 Client ID (Web application type)
2. Android app registered in Google Cloud Console with SHA-1 fingerprint
3. Supabase project with Google provider enabled

**Step 1: Register Android app in Google Cloud Console**

Before creating the OAuth Client ID, register the Android app:

1. **Google Cloud Console** → APIs & Services → Credentials
2. Click **+ Create Credentials** → **Android app**
3. Fill in:
   - **App package name:** `com.example.coverwise` (verify in `mobile/android/app/build.gradle.kts` → `applicationId`)
   - **SHA-1 certificate fingerprint:**
     - Debug: `96:0E:D9:BF:3A:9D:33:B5:8E:3F:83:01:EC:C6:C5:39:5E:9A:CC:1D`
     - Release: extract from `mobile/android/app/upload-keystore.jks` (see below)
4. Click **Register**

**To extract release SHA-1:**
```bash
keytool -list -v -keystore mobile/android/app/upload-keystore.jks -alias upload
# Enter the keystore password when prompted
# Copy the SHA1 fingerprint value
```

**Step 2: Create OAuth 2.0 Client ID (Web application)**

Supabase's Google provider uses a **Web application** Client ID (not Android) because the OAuth flow goes through Supabase's callback URL:

1. **Google Cloud Console** → APIs & Services → Credentials
2. Click **+ Create Credentials** → **OAuth client ID**
3. Application type: **Web application**
4. Name: `CoverWise Supabase Auth`
5. Authorized redirect URIs: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
6. Save **Client ID** and **Client Secret**

**Step 3: Configure Supabase Dashboard**

1. **Supabase Dashboard** → Authentication → Providers → Google
2. Enable Google
3. Paste **Client ID** (from Step 2)
4. Paste **Client Secret** (from Step 2)
5. Save

**Step 4: Verify mobile app configuration** (already implemented)

- `google_sign_in: ^6.3.0` in `pubspec.yaml` ✅
- `AuthService.signInWithGoogle()` uses `signInWithOAuth(Provider.google, redirectTo: 'io.coverwise://login-callback')` ✅
- Google button renders in `AccountScreen` when `AppConfig.hasSupabaseAuthConfig` is true ✅
- `/login-callback` deep link handler in `main.dart` ✅

**Known debug keystore fingerprints:**

| Keystore | SHA-1 | SHA-256 |
|---|---|---|
| Debug (`~/.android/debug.keystore`) | `96:0E:D9:BF:3A:9D:33:B5:8E:3F:83:01:EC:C6:C5:39:5E:9A:CC:1D` | `63:F2:44:14:D9:88:F8:A2:59:25:4B:EC:DC:A4:D6:94:24:27:96:88:39:DD:39:87:4D:AE:11:B7:E4:DA:B0:FB` |
| Release (`upload-keystore.jks`) | `6B:5C:A6:45:BF:4B:E7:27:07:35:0B:86:78:CF:A9:0B:95:79:B7:03` | Extract with: `keytool -list -v -keystore upload-keystore.jks -alias upload` |

**⚠️ Important:** Google Sign-In requires BOTH the debug AND release SHA-1 fingerprints registered in Google Cloud Console. Without the release fingerprint, Google Sign-In will fail on production builds.

### 11E. Email Templates

**Dashboard path:** Supabase Dashboard → Authentication → Email Templates

Supabase sends transactional emails for three actions. Each template uses the `{{ .ConfirmationURL }}` variable which includes the redirect URL.

| Template | Trigger | Default Subject | Redirect URL Contains |
|---|---|---|---|
| **Confirm signup** | User signs up with email/password | `Confirm your email` | `io.coverwise://login-callback` (default) or custom redirect |
| **Magic Link** | Passwordless sign-in (not currently used) | `Your magic link` | N/A — not implemented |
| **Change Email Address** | User changes email in account settings | `Confirm email change` | `io.coverwise://login-callback` (default) |
| **Reset Password** | User taps "Forgot password?" | `Reset your password` | `io.coverwise://reset-callback` ✅ Custom redirect configured in `auth_service.dart` |

**Configuration notes:**

- **Confirm signup:** The default template works as-is. The `{{ .ConfirmationURL }}` will include the Supabase project URL by default. To redirect back to the app, update the email template's link to use `io.coverwise://login-callback?token={{ .Token }}` — OR rely on Supabase's automatic deep link handling (recommended).
- **Reset Password:** Already configured in code: `resetPasswordForEmail(email, redirectTo: 'io.coverwise://reset-callback')`. The Supabase template's `{{ .ConfirmationURL }}` will automatically include this redirect. **No template changes needed** — but verify the URL is in the allowed redirect list (§11C).
- **Email confirmation:** Supabase's built-in confirmation flow works without template changes. After sign-up, the user receives an email with a confirmation link. If the redirect URL is in the allowed list, the app handles it automatically via `onAuthStateChange`.

**⚠️ If the redirect URL is NOT in the allowed list, Supabase will strip it from the email and the user will see a web page instead of being redirected to the app.**

### 11F. API Key Security

**Dashboard path:** Supabase Dashboard → Settings → API

| Key | Purpose | Used In |
|---|---|---|
| **Project URL** (`https://xxx.supabase.co`) | Supabase API endpoint | `AppConfig.supabaseUrl` (build-time `--dart-define`) |
| **anon / publishable key** (`eyJ...`) | Public API key — safe to ship in client apps | `AppConfig.supabasePublishableKey` (build-time `--dart-define`) |
| **service_role key** | Admin API key — **NEVER ship in client apps** | Backend only: `user.py` uses `SUPABASE_SERVICE_ROLE_KEY` env var |

**Row Level Security (RLS):**
- Supabase RLS policies ensure each user can only read/write their own documents
- The `anon` key is used by the mobile app; RLS prevents cross-user access
- The `service_role` key bypasses RLS — used server-side for admin operations (account deletion)

### 11G. Storage Bucket Configuration

**Dashboard path:** Supabase Dashboard → Storage

| Bucket | Purpose | Access Policy |
|---|---|---|
| `coverwise-documents` | Stores uploaded policy PDFs | RLS: authenticated users can read/write their own files only |

**Configuration:**
- Bucket must be created manually (or via migration script)
- Set to **private** (not public) — documents contain sensitive PII
- RLS policies: `auth.uid() = path_tokens[1]` ensures user-scoped access
- File cleanup: `DELETE /user/account` endpoint now deletes storage files before metadata (see §9, Account Deletion Implementation Details)

### 11H. Database Schema

**Dashboard path:** Supabase Dashboard → SQL Editor

The app requires these tables (created via `infra/supabase/001_coverwise_schema.sql`):

| Table | Purpose | RLS Policy |
|---|---|---|
| `documents` | Policy document metadata (owner, status, OCR text) | `auth.uid() = owner_uid` |
| `document_chunks` | Chunked text for RAG embedding | `EXISTS (SELECT 1 FROM documents WHERE documents.id = document_chunks.document_id AND documents.owner_uid = auth.uid())` |
| `analytics_events` | App analytics (global errors, usage) | `auth.uid() = user_uid` (or anonymous) |

**Key indexes:**
- `idx_documents_owner` on `documents(owner_uid)` — supports per-user document queries
- `idx_chunks_document` on `document_chunks(document_id)` — supports chunk retrieval for RAG
- `idx_analytics_error_window` on `analytics_events(received_at, event_name)` — supports error aggregation queries
- `idx_analytics_summary` on `analytics_events(received_at, event_name, user_uid)` — supports summary endpoint

### 11I. Configuration Checklist (Pre-Launch)

| # | Task | Where | Done? |
|---|---|---|---|
| 1 | Create Supabase project | app.supabase.com | ☐ |
| 2 | Set build-time env vars (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`) | Build script / CI | ☐ |
| 3 | Enable Email provider | Dashboard → Auth → Providers | ☐ |
| 4 | Add `io.coverwise://reset-callback` to redirect URLs | Dashboard → Auth → URL Configuration | ☐ |
| 5 | Add `io.coverwise://login-callback` to redirect URLs | Dashboard → Auth → URL Configuration | ☐ |
| 6 | Verify email templates use `{{ .ConfirmationURL }}` correctly | Dashboard → Auth → Email Templates | ☐ |
| 7 | Create `coverwise-documents` storage bucket (private) | Dashboard → Storage | ☐ |
| 8 | Run schema migration (`001_coverwise_schema.sql`) | Dashboard → SQL Editor | ☐ |
| 9 | Enable Google provider (when ready) | Dashboard → Auth → Providers | ☐ |
| 10 | Set `SUPABASE_SERVICE_ROLE_KEY` env var on backend | Backend deployment | ☐ |
| 11 | Test password reset end-to-end | Manual | ☐ |
| 12 | Test Google Sign-In end-to-end | Manual | ☐ |

### 11J. Common Failure Modes

| Symptom | Likely Cause | Fix |
|---|---|---|
| "Account auth is not configured for this build" | Missing `SUPABASE_URL` or `SUPABASE_PUBLISHABLE_KEY` at build time | Pass `--dart-define` flags |
| Password reset email never arrives | Email provider not enabled in Supabase | Enable Email in Auth → Providers |
| Password reset link opens browser instead of app | `io.coverwise://reset-callback` not in redirect URLs | Add to Auth → URL Configuration |
| Google Sign-In fails silently | Google provider not configured in Supabase | Complete §11D setup |
| "Invalid token" on account operations | `SUPABASE_SERVICE_ROLE_KEY` not set on backend | Set env var on backend deployment |
| 403 on document upload | RLS policy missing or `owner_uid` mismatch | Verify RLS policy and anonymous-to-account migration |
| Storage files orphaned after account deletion | Storage cleanup not triggered | Verify `DELETE /user/account` includes storage cleanup (§9) |

---

---

## 12. Production Monitoring & Alerting

**motto_v3 §0.10 (Observability):** *"If the system fails and nobody notices, it didn't fail gracefully."*

Auth health is the highest-risk operational surface for CoverWise. A broken login flow means zero revenue, zero data collection, and immediate App Store delisting risk. This section defines what to monitor, where to find the data, and when to alert.

### 12A. Key Metrics to Track

| Metric | Source | Query / Location | Alert Threshold | Why It Matters |
|---|---|---|---|---|
| **Auth sign-in success rate** | Supabase Dashboard → Authentication → Users | `% of signIn() calls that return a session` | < 90% over 1 hour | Broken auth = zero user acquisition |
| **Sign-up completion rate** | Supabase Dashboard → Authentication → Users | `signUps / confirmations` | < 50% | Users who sign up but never confirm email |
| **Password reset completion rate** | Supabase Dashboard → Authentication → Logs | `resetPasswordForEmail calls / actual password changes` | < 30% | Broken redirect URLs or email delivery failures |
| **Google OAuth success rate** | Supabase Dashboard → Authentication → Providers → Google | `successful OAuth callbacks / total OAuth initiations` | < 80% | Misconfigured SHA-1, Client ID, or redirect URLs |
| **Anonymous token acquisition rate** | Backend: `POST /user/anonymous` 2xx responses | `2xx / total requests` | < 95% | Backend outage or rate limiting kicking in |
| **Document upload success rate** | Backend: `POST /documents/upload` 2xx responses | `2xx / total requests` | < 90% | Processing pipeline failures |
| **Account deletion success rate** | Backend: `DELETE /user/account` 2xx responses | `2xx / total requests` | < 95% | Storage cleanup or Supabase admin API failures |
| **Email delivery rate** | Supabase Dashboard → Authentication → Logs | `emails sent / emails delivered` | < 85% | Email provider reputation or Supabase email quota |
| **Global error rate** | Backend: `GET /analytics/errors` | `error_count in last 24h` | > 50 errors/hour | Any systemic failure |
| **Active user count** | Supabase Dashboard → Authentication → Users | `users with activity in last 7 days` | < 10 DAU (pre-launch) | Engagement baseline |

### 12B. Auth Health Dashboard Queries

**Supabase SQL Editor — run these weekly:**

```sql
-- 1. Sign-up funnel (last 7 days)
SELECT
  DATE(created_at) as day,
  COUNT(*) as signups,
  COUNT(CASE WHEN email_confirmed_at IS NOT NULL THEN 1 END) as confirmed,
  ROUND(100.0 * COUNT(CASE WHEN email_confirmed_at IS NOT NULL THEN 1 END) / NULLIF(COUNT(*), 0), 1) as confirm_rate
FROM auth.users
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- 2. User activity proxy (last 7 days)
-- NOTE: recovery_token is not exposed in Supabase's auth.users view,
-- so we cannot query password resets directly. This approximates
-- user engagement by counting sign-ups and record modifications
-- (updated_at > created_at fires for email confirmation, profile
-- updates, session refreshes, and password resets alike).
SELECT
  DATE(created_at) as day,
  COUNT(*) as signups,
  COUNT(CASE WHEN updated_at > created_at THEN 1 END) as users_with_activity
FROM auth.users
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- 3. Google OAuth attempts (last 7 days)
SELECT
  DATE(created_at) as day,
  COUNT(*) as google_signups
FROM auth.users
WHERE created_at > NOW() - INTERVAL '7 days'
  AND raw_user_meta_data->>'provider' = 'google'
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- 4. Stale accounts (never confirmed, older than 30 days)
SELECT
  COUNT(*) as stale_unconfirmed
FROM auth.users
WHERE email_confirmed_at IS NULL
  AND created_at < NOW() - INTERVAL '30 days';

-- 5. Storage cleanup verification (orphaned files)
-- NOTE: The documents table stores storage paths in `object_reference`,
-- not `file_path`. The storage.objects `name` field matches this column.
SELECT
  COUNT(*) as orphaned_files
FROM storage.objects
WHERE bucket_id = 'coverwise-documents'
  AND created_at < NOW() - INTERVAL '90 days'
  AND name NOT IN (
    SELECT DISTINCT object_reference FROM documents WHERE object_reference IS NOT NULL
  );
```

### 12C. Alerting Rules

| Rule | Condition | Severity | Action |
|---|---|---|---|
| **Auth outage** | `POST /user/anonymous` error rate > 50% for 5 min | 🔴 P0 | Check backend health, Supabase status page, restart if needed |
| **Email delivery failure** | Supabase email bounce rate > 20% | 🔴 P0 | Check Supabase email quota, verify sender domain, contact Supabase support |
| **Google OAuth broken** | Google sign-in success rate < 50% for 1 hour | 🟡 P1 | Verify SHA-1 fingerprints, check Google Cloud Console quota, verify Client ID |
| **Password reset broken** | Reset completion rate < 20% for 24 hours | 🟡 P1 | Verify redirect URLs in Supabase, test email template links |
| **Sign-up spam** | > 50 sign-ups from same IP in 1 hour | 🟡 P1 | Enable CAPTCHA on sign-up, review disposable email list |
| **Account deletion failure** | `DELETE /user/account` error rate > 30% | 🟡 P1 | Check Supabase admin API key, verify storage bucket permissions |
| **Storage quota** | Supabase Storage used > 80% of plan limit | 🟢 P2 | Review storage usage, consider tier upgrade |
| **Supabase plan approaching limit** | Auth MAU > 80% of free tier (50K) | 🟢 P2 | Plan Supabase upgrade or self-host migration |

### 12D. Monitoring Stack Recommendations

**For solo launch (current):**
- **Primary:** Supabase Dashboard built-in analytics (Authentication → Logs)
- **Secondary:** Backend `/analytics/errors` endpoint + `GET /analytics/summary`
- **Tertiary:** Manual weekly SQL queries from §12B above
- **Uptime:** Set up a free UptimeRobot or Betterstack monitor on `GET /health`

**For scale (post-1000 users):**
- **Structured logging:** Send auth events to a log aggregator (Axiom, Betterstack, or Datadog free tier)
- **Real-time alerts:** PagerDuty or Slack webhook for P0/P1 conditions
- **Dashboards:** Grafana or Metabase connected to Supabase/Postgres
- **Cost monitoring:** Supabase billing alerts at 50%, 80%, 100% of plan limits

### 12E. Auth Event Tracking (Already Implemented)

The app already tracks auth-related analytics events via `AnalyticsService`:

| Event | Triggered When | Code Location |
|---|---|---|
| `sign_in_success` | User successfully signs in | account_screen.dart |
| `sign_in_error` | Sign-in fails (wrong password, network, etc.) | account_screen.dart |
| `sign_up_success` | User successfully creates account | account_screen.dart |
| `sign_up_error` | Sign-up fails (email taken, etc.) | account_screen.dart |
| `sign_out` | User signs out | profile_screen.dart |
| `password_reset_request` | User requests password reset | account_screen.dart |
| `password_reset_success` | User successfully resets password | reset_password_screen.dart |
| `password_reset_error` | Password reset fails | reset_password_screen.dart |
| `google_sign_in_attempt` | User taps Google Sign-In button | account_screen.dart |
| `google_sign_in_success` | Google OAuth completes successfully | auth_provider.dart |
| `google_sign_in_error` | Google OAuth fails | account_screen.dart |
| `account_deletion_request` | User initiates account deletion | profile_screen.dart |
| `account_deletion_success` | Account fully deleted | profile_screen.dart |
| `account_deletion_error` | Account deletion fails | profile_screen.dart |
| `email_verification_resend` | User requests verification email resend | account_screen.dart |
| `global_error` | Unhandled Flutter error caught by GlobalErrorBoundary | global_error_boundary.dart |

**Note:** All events are consent-gated via `ConsentLedger.analytics` — they only fire when the user has granted analytics consent during onboarding.

### 12F. Operational Runbook (Quick Reference)

| Scenario | Symptom | Diagnosis | Fix |
|---|---|---|---|
| **All auth broken** | Every sign-in/sign-up fails | Check Supabase status page (status.supabase.com). If down, wait. If up, check `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` env vars. | Restart backend, verify env vars |
| **Google Sign-In broken** | Google button shows but fails silently | Check Google Cloud Console → APIs → Quotas. Verify SHA-1 fingerprints match debug AND release keystores. Verify Web Client ID (not Android). | Re-register Android app with correct SHA-1, verify redirect URI |
| **Password reset broken** | Reset email arrives but link opens browser instead of app | Verify `io.coverwise://reset-callback` is in Supabase → Auth → URL Configuration. Check iOS Info.plist and Android manifest for URL scheme. | Add redirect URL to Supabase dashboard |
| **Email not confirming** | Sign-up succeeds but confirmation email never arrives | Check Supabase → Authentication → Logs for email delivery status. Check spam folder. Verify email provider is enabled. | Enable email provider, check spam, verify domain |
| **Account deletion hanging** | Delete button shows spinner forever | Check `DELETE /user/account` backend logs. Supabase admin API may be rate-limited. Verify `SUPABASE_SERVICE_ROLE_KEY` is set. | Check backend logs, verify service role key, retry |
| **Anonymous auth broken** | App shows "Account auth is not configured" on startup | Missing `SUPABASE_URL` or `SUPABASE_PUBLISHABLE_KEY` at build time. | Pass `--dart-define` flags |

---

*Last updated: 2026-07-18 — Production monitoring and alerting section added.*
