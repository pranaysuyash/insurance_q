# ADR-2026-07-21-07: Encrypted Model Run Implementation

## Context
- All LLM-based operations (policy extraction, compliance checks) must use principal-key encrypted storage
- ADR-2026-07-21-05 requires end-to-end source-traceable outputs

## Implementation
1. **Policy Extractor Adapter**
   - Wrap `PolicyExtractionService` with DEK encryption:
   ```dart
   class EncryptedPolicyExtractor {
     final Uint8List _dek = PrincipalKeyService.getOrThrow();
     Future<Uint8List> extractSummary(String text) async {
       final raw = await policyService.extractSummary(text);
       return Crypto.encryptAes256(_dek, raw);
     }
   }
```

2. **CIR Evidence Annotation**
   - Add `encrypted_metadata` field to CIR nodes:
   ```typescript
   interface CIRNode {
     encryptedMetadata: { hash: string; timestamp: string };
   }
   ```

3. **Model Run Logging**
   - Create encrypted model_run_results table in Supabase:
   ```sql
   CREATE TABLE model_run_results {
     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
     encrypted_output_hash TEXT NOT NULL CHECK LENGTH(output_hash) = 64,
     policy_summary_hash TEXT NOT NULL,
     created_at TIMESTAMPTZ DEFAULT NOW()
   }
```