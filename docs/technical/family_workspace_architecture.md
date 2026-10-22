# Family Workspace Architecture & Sync Protocol

## 1. Context & Motivation
Under the CoverWise mobile application, insurance policies frequently protect multiple family members across health, life, vehicle, and property domains. Previously, policy extraction stored manual family members exclusively in local \`SharedPreferences\` / \`AppStateRepository\`, creating siloed device state with no multi-device synchronization or backend auditability.

To resolve this while preserving the local-first, offline-ready doctrine (\`OPERATING_DOCTRINE.md\` §2, §6.1), the Family Workspace architecture introduces a robust two-way sync protocol between the Flutter mobile client (\`FamilySyncService\`) and the Supabase backend (\`/api/v1/family\`).

---

## 2. System Architecture

\`\`\`mermaid
graph TD
    A[Mobile UI: Family Member Sheet] -->|Mutations| B[FamilySyncService]
    B -->|Persist Locally| C[(AppStateRepository / SharedPreferences)]
    B -->|Network Available?| D{Connectivity Check}
    D -->|Yes| E[POST /api/v1/family/sync]
    D -->|No / Offline| F[Offline Mutation Queue]
    E --> G[FastAPI Backend Router: src/api/family.py]
    G --> H[(Supabase Postgres: family_members table)]
    F -->|On Reconnect| E
    H -->|Reconciled State| G
    G -->|200 OK + Reconciled List| B
    B -->|Notify| I[FamilyNotifier / Providers]
    I -->|Re-render UI| A
\`\`\`

---

## 3. Database Schema (\`20260824000000_family_workspace.sql\`)

\`\`\`sql
CREATE TABLE IF NOT EXISTS family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    relation TEXT NOT NULL,
    age INTEGER CHECK (age >= 0 AND age <= 130),
    is_dependent BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- RLS Policies
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only read their own family workspace"
    ON family_members FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own family workspace"
    ON family_members FOR ALL
    USING (auth.uid() = user_id);
\`\`\`

---

## 4. Sync Protocol & Conflict Resolution

### 4.1. Two-Way Reconciliation Strategy
1. **Pull on App Startup**: When \`FamilySyncService.sync()\` is called, the client pulls the server state via \`GET /api/v1/family/\`.
2. **Local Overwrite vs. Merge**:
   - Every member has a unique \`id\` (UUID generated on creation, or preserved from server).
   - If a member exists locally with no server \`id\` (offline creation), it is batched into the sync payload.
   - For members existing in both local and remote stores, the higher updated timestamp wins (last-write-wins).
   - Deletions are soft-deleted locally with a deletion tombstone or immediate \`DELETE /api/v1/family/{id}\` if online.
3. **Offline Fallback**:
   - If the backend is unreachable (\`SocketException\` or network timeout), the client gracefully catches the failure, preserves the local state in \`AppStateRepository\`, and schedules synchronization for the next app launch or network reconnection.

### 4.2. Flutter Implementation
- \`mobile/lib/services/family_sync_service.dart\`: Encapsulates all network requests, JSON serialization, and local state synchronization.
- \`mobile/lib/providers/family_providers.dart\`: Riverpod integration ensuring UI widgets reactively observe synced family state.

---

## 5. Security & Privacy Guarantees
- **Authentication**: All backend endpoints require standard Bearer token verification (\`user_id\` extracted from JWT claims).
- **Row-Level Security**: Postgres RLS policies ensure users cannot view or mutate family records across user boundaries.
- **Sensitivity Tier (S1)**: PII (names, relations, ages) is transmitted exclusively over TLS 1.3, encrypted at rest in Postgres, and never logged in plain text.

---

## 6. Verification & Test Evidence
- **Backend Tests**: \`tests/test_family_api.py\` (4/4 passed).
- **Mobile Tests**: \`mobile/test/family_sync_service_test.dart\` (2/2 passed).
- **Offline Sweep**: Zero regressions across existing test suites.
