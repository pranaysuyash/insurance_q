# Mobile Security Architecture

This document outlines the security architecture specifically for the mobile application (Flutter).

_This is a placeholder document. Please populate with details about mobile security measures._

> **Historical note:** The authentication reference below is for legacy migration
> context only. The active runtime contract uses Supabase Auth and canonical
> RLS-driven ownership patterns documented in
> [`../../architecture/coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md).

## Key Areas:
- Authentication (Supabase Auth — historical Firebase wording kept as migration context)
- Secure API communication (HTTPS, token handling)
- Data storage on the device (encryption, secure storage)
- Code obfuscation
- Jailbreak/root detection
- Secure handling of sensitive data (API keys, user info)
- Biometric authentication integration 
