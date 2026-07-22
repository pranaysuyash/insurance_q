# CoverWise Privacy Policy

**Effective Date:** July 20, 2026  
**Last Updated:** July 20, 2026

## Introduction

CoverWise ("we," "our," or "us") helps you store and understand your insurance policies by extracting key information and answering questions grounded in your uploaded documents. This Privacy Policy explains what data we collect, how we protect it, and your privacy rights.

We are a **policy information assistant** — we help you understand your insurance documents. We do not sell insurance, provide financial advice, or act as an insurer or broker.

## What We Collect

### Data You Provide
- **Policy documents:** PDFs and images you upload for processing
- **Your questions:** Questions you ask about your policies
- **Account information:** Email address if you create an account (optional)

### Data We Generate
- **Policy summaries:** Extracted key information from your documents
- **Search indexes:** Vector embeddings for finding relevant policy sections
- **Usage analytics:** Anonymous event counts and feature usage patterns (opt-in)

### Data We Do NOT Collect
- Financial information or payment details
- Health information beyond what appears in your policy documents
- Location data
- Contact lists or phone contacts

## How We Use Your Data

| Purpose | Data Used | Storage Location |
|---------|-----------|------------------|
| Policy processing | Your uploaded documents | Supabase Storage (encrypted) |
| Q&A answers | Your questions + policy text | Backend (temporary) |
| Search functionality | Vector embeddings of policy text | Supabase pgvector |
| App improvement | Anonymous usage events | SQLite + Supabase |

## Data Processing

When you upload a policy:
1. The document is stored in private Supabase Storage
2. Text is extracted via OCR (on-device or server-side)
3. Key information is summarized using AI (OpenAI API)
4. Vector embeddings are created for search functionality

**Sub-processors:**
- **Supabase:** Private storage and database (encrypted at rest)
- **OpenAI:** Text analysis and answer generation (data not used for training)

## Data Retention

| Data Type | Retention Period | Deletion Method |
|-----------|------------------|-----------------|
| Policy documents (local) | Until you delete | Settings → Clear local data |
| Policy documents (server) | Until account deletion | Account deletion request |
| Q&A history | Local only | Settings → Clear local data |
| Analytics events | 30 days | Automatic purge |
| Account data | Until deletion | Account deletion |

## Your Rights

### Access and Portability
- View all data we hold about you in the app
- Export your policy summaries and Q&A history

### Correction
- Edit extracted policy information directly in the app
- Request correction of any inaccurate data

### Deletion
- Delete all local data anytime via Settings
- Request account deletion (server-side processing within 30 days)
- Note: Server deletion is best-effort; partial deletions are reported honestly

### Consent
- Toggle analytics consent anytime in Settings → Privacy
- Withdraw document processing consent by deleting the document
- Consent is recorded in an auditable ledger with timestamp and version

## Security

- All communication encrypted via HTTPS/TLS
- API keys stored as environment variables, never in app code
- Rate limiting prevents abuse
- Anonymous device identity protects your documents

## Children's Privacy

CoverWise is not intended for users under 13. We do not knowingly collect data from children.

## Changes to This Policy

We may update this policy. Changes will be reflected in the app with the effective date. Continued use constitutes acceptance.

## Contact

For privacy questions or data requests:
- Email: [support@coverwise.app](mailto:support@coverwise.app)
- In-app: Settings → Help & Support

## Legal Basis (GDPR)

If you are in the European Economic Area, we process your data based on:
- **Consent:** Analytics and optional features
- **Contract:** Providing the CoverWise service you requested
- **Legitimate interest:** Improving the app and preventing abuse

---

*CoverWise helps you understand your insurance policies. It does not provide insurance, financial, or legal advice.*
