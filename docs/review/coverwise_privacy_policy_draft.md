# CoverWise Privacy Policy Draft

## Addendum (2026-07-16): advertising and model-improvement boundary

This is drafting direction for product and legal review, not publish-ready legal text.

- CoverWise does not use policy documents, extracted contents, questions, answers, health, claim, family, or financial details to select behavioral advertisements.
- CoverWise does not sell these data types or disclose them to data brokers.
- Core product data is not used to train shared CoverWise models by default.
- Any contribution program must use a separate optional consent flow describing exact data, purpose, safeguards, retention, withdrawal, and effects. Declining must not block core use.
- Analytics remains limited to documented non-content events and coarse operational properties. Policy text, questions, answers, filenames, identifiers, and feedback comments must not enter analytics payloads.
- Any future sponsor placement must be contextual, labeled, independent of profile and contents, and absent from policy, Q&A, claim, emergency, family, and gap workflows.
- The published policy must name the entity, processors, model/analytics/payment providers, locations, retention, rights channel, deletion behavior, grievance contact, and effective date.

Implementation and commercial detail: [`docs/planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md`](../planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md).

**Status:** review required before publication  
**Last updated:** 2026-07-12

> This is a product-aligned draft, not legal advice. Replace every bracketed value and have the operator review it against the deployed data flow before publishing.

## Who operates CoverWise

CoverWise is operated by **[LEGAL ENTITY NAME]**, located at **[BUSINESS ADDRESS/JURISDICTION]**. Privacy questions can be sent to **[PRIVACY EMAIL]**.

## What we receive

Depending on the release configuration, CoverWise may receive:

- Documents that a user chooses to upload for processing.
- Questions submitted about an uploaded document.
- Technical information needed to secure and operate the service.
- Support messages that a user chooses to send.

The final policy must be narrowed to the actual deployed behavior. Do not publish this list until engineering has confirmed the storage, logging, model-provider, and deletion paths.

## Why we use it

We use submitted information to provide document processing and explanations, maintain service security, measure reliability, respond to support requests, and meet legal obligations where applicable.

We do not use policy documents or inferences from them for advertising. The current product direction does not permit policy-targeted advertising even with an ordinary consent prompt; changing that boundary would require a new product decision, optional external review, and a rewritten privacy architecture.

## Sensitive documents

Insurance documents may contain personal or sensitive information. Users should upload only documents they are comfortable processing through the configured service and should redact information that is not needed where practical.

## Service providers

The final policy must list the categories and names of any hosting, storage, OCR, model, analytics, crash-reporting, and support providers that process data, plus the relevant transfer safeguards.

## Retention and deletion

**[INSERT ACTUAL RETENTION PERIOD AND DELETION MECHANISM]**

The published policy must match actual runtime behavior, including backups, logs, model-provider retention, failed uploads, and user-requested deletion.

## User choices and rights

Users may contact **[PRIVACY EMAIL]** to ask about access, correction, deletion, or other rights available in their jurisdiction. Identity verification and response timelines should be described after the owner finalizes operational commitments (and optional external review if you want).

## Children

CoverWise is not directed to children under **[AGE/JURISDICTION RULE]**. The operator should confirm the intended age policy before publication.

## Changes

We may update this policy when the service or legal requirements change. The published page will show its effective date.

## Approval gate

Do not link this draft from the production website or Play Store until the bracketed values are resolved and the final text has been reviewed by the operator (or an external reviewer of your choice).
