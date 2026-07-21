# CoverWise India Billing Decision: RevenueCat, App Store/Play Billing, Dodo Payments, and Business Entity Requirements

**Decision date:** 2026-07-21  
**Product:** CoverWise  
**Operating company:** PSRS Technologies Private Limited  
**Market considered:** India-first consumer mobile application  
**Decision type:** Billing-provider and distribution architecture  
**Status:** Recommended direction, subject to store onboarding, tax/accounting review, and sandbox verification  
**Evidence basis:** Current official documentation from RevenueCat, Apple, Google Play, and Dodo Payments

---

## 1. Decision Summary

CoverWise should use:

```text
iOS:
Apple In-App Purchase
        +
RevenueCat
        +
CoverWise server-side entitlement and usage ledger

Android:
Google Play Billing
        +
RevenueCat
        +
CoverWise server-side entitlement and usage ledger
```

Dodo Payments should **not replace RevenueCat for the initial native mobile launch**.

Dodo may later be used for:

- purchases on the CoverWise website;
- UPI and Indian-card checkout;
- web subscriptions;
- invoices and Merchant-of-Record support;
- an optional Android alternative-billing path in India, only after the ordinary Google Play/RevenueCat lifecycle is stable.

RevenueCat’s own **web-billing engine** should not currently be chosen for Indian customers because RevenueCat documents that it does not collect the full billing-address information required for India.

---

## 2. Is RevenueCat Available in India?

### Native mobile purchases

Yes.

RevenueCat supports countries supported by its connected stores. For native mobile purchases, RevenueCat is not the payment processor. Apple App Store or Google Play processes the transaction, pays the developer, and applies its platform rules. RevenueCat provides:

- SDK integration;
- receipt and transaction normalization;
- entitlement state;
- subscription status;
- offerings and paywalls;
- restoration;
- analytics;
- lifecycle events and webhooks.

India is therefore supported through Apple and Google’s Indian storefronts.

### RevenueCat web billing

This is a different product.

RevenueCat Billing uses Stripe as its payment gateway and manages web subscriptions. RevenueCat currently documents that this billing engine cannot be used in India because it does not collect and store the customer’s full billing address.

| RevenueCat capability | India status |
|---|---|
| Apple App Store purchases | Supported where Apple IAP is supported |
| Google Play purchases | Supported where Google Play Billing is supported |
| RevenueCat SDK/entitlements | Supported |
| RevenueCat Billing for web checkout | Currently unsuitable for India |
| RevenueCat account creation | Available with an email address |

---

## 3. Does RevenueCat Require a Business Entity?

RevenueCat itself does not require incorporation merely to create an account.

Its documentation says:

- an account can be created with an email address;
- a company-owned account is recommended for organizations and teams;
- company, address, and tax details can be added for RevenueCat invoices.

The entity and payout requirements primarily come from Apple, Google, banks, tax obligations, and the selected web payment provider.

---

## 4. Apple Developer Requirements in India

Apple supports both individual and organization enrollment.

### Individual enrollment

- An individual or sole proprietor may enroll.
- The developer’s personal legal name appears as the App Store seller.
- No D-U-N-S number is required.

### Organization enrollment

- The organization must be a legal entity.
- The legal entity name appears as the App Store seller.
- A D-U-N-S number is required.
- The enrolling person must have authority to bind the organization.
- Apple expects an organization-domain work email and a functional public website.
- Apple notes that enrollment in India is completed through the Apple Developer app.

### CoverWise recommendation

Use an Apple Developer **organization account under PSRS Technologies Private Limited**.

Benefits:

- PSRS appears as the seller rather than Pranay’s personal name;
- ownership survives personnel and account changes;
- team access and future support are easier;
- transfer and compliance history are cleaner;
- RevenueCat, App Store Connect, banking, and tax records can use the same entity.

---

## 5. Google Play Developer Requirements

Google Play offers personal and organization accounts. Both can monetize through a payments profile.

Google says an organization account should be used for a commercial organization or business, and a D-U-N-S number is required. Google also explicitly requires organization accounts for specified financial-services and health-app categories.

CoverWise’s final classification depends on its shipped features and Play Console declarations. Even if it is ultimately classified as a policy-document utility rather than a regulated financial or health app, an organization account is the safer and more coherent choice.

### CoverWise recommendation

Use a Google Play **organization account under PSRS Technologies Private Limited**.

---

## 6. Can Dodo Payments Replace RevenueCat for Native In-App Purchases?

Not as a general replacement.

| System | Main role |
|---|---|
| RevenueCat | Normalizes Apple/Google purchases, receipts, subscriptions, entitlements, restoration, webhooks, and analytics |
| Dodo Payments | External checkout and Merchant of Record for supported web or alternative-payment transactions |
| Apple/Google | Native app-store billing, storefront policy, store receipt, subscription management, payout |
| CoverWise backend | Principal ownership, authorization, usage ledger, product capabilities, deletion, and reconciliation |

Using Dodo does not remove Apple and Google’s store-policy requirements.

---

## 7. Dodo on iOS in India

Dodo’s digital-goods documentation says alternative iOS purchase flows are available only in App Store regions where Apple explicitly permits them.

The currently listed supported regions include:

- United States;
- European Union under Apple’s alternative terms and entitlements;
- South Korea under a Korea-specific external-purchase entitlement.

India is not listed as an eligible iOS alternative-payment region.

Therefore Dodo should not be used as the in-app checkout for CoverWise digital subscriptions or Q&A packs for Indian iOS users.

```text
Apple IAP
  -> RevenueCat
  -> CoverWise entitlement ledger
```

---

## 8. Dodo on Android in India

Google permits developers serving Indian users to offer an alternative billing system **alongside Google Play Billing**, subject to program requirements.

Important conditions include:

- Google Play Billing remains offered as a choice;
- the developer must integrate the applicable alternative-billing APIs and UX;
- alternative transactions must be reported to Google within 24 hours;
- Google’s service fee still applies, with a four-percentage-point reduction for alternative-billing transactions;
- refunds, cancellations, subscription lifecycle, and entitlement state must be reconciled across both systems.

Dodo could therefore become an Android alternative-billing provider in India, but it creates a multi-provider system:

```text
Google Play Billing + RevenueCat
             and
Dodo checkout
             and
Google alternative-billing reporting
             and
one CoverWise financial ledger
```

### Decision

Do not add Dodo alternative billing to the first Android paid release.

Reconsider only after:

- Google Play Billing works end to end;
- RevenueCat principal identity is stable;
- webhook reconciliation is active;
- entitlements are server-authoritative;
- refunds and reinstalls are tested;
- conversion evidence suggests UPI materially improves paid conversion.

---

## 9. Dodo for Indian Web Purchases

Dodo is well suited to future Indian web checkout.

Its documentation states support for:

- UPI;
- Indian-issued Visa, Mastercard, and RuPay cards;
- INR pricing;
- subscriptions using RBI-compliant mandates;
- Merchant-of-Record services;
- tax handling, invoicing, fraud, and chargebacks.

Indian recurring payments have special lifecycle requirements. Dodo documents a roughly 48-hour processing delay for recurring debits under the applicable mandate flow and warns not to grant renewed access until a `payment.succeeded` webhook is received.

```text
Dodo checkout
  -> verified webhook
  -> CoverWise billing event
  -> CoverWise entitlement projection
  -> mobile/web access
```

Do not grant access merely when renewal collection is initiated.

---

## 10. Business Entity Recommendation

CoverWise can technically begin RevenueCat experimentation without a company account.

For production distribution and payment operations, use PSRS Technologies Private Limited consistently across:

- Apple Developer organization account;
- App Store Connect;
- Google Play organization account;
- Google payments profile;
- RevenueCat project ownership;
- Dodo merchant account if added;
- support email and legal pages;
- payout bank account;
- invoices and tax records;
- privacy-controller and contracting identity.

Recommended ownership:

```text
PSRS-controlled domain email
  -> Apple Developer Account Holder
  -> Google Play account owner
  -> RevenueCat project owner
  -> Dodo merchant owner
```

Avoid making a personal email the permanent commercial owner.

---

## 11. CoverWise Billing Architecture Decision

### Native mobile launch

Use:

- Apple IAP for iOS;
- Google Play Billing for Android;
- RevenueCat for store abstraction;
- a CoverWise server-side billing-event ledger;
- a server-side entitlement projection;
- a server-side usage ledger for Q&A and capacity;
- store-derived localized prices;
- stable CoverWise principal IDs mapped to RevenueCat customers.

### Web billing later

Evaluate Dodo first for India-focused web billing because of UPI, Indian cards, RBI mandate support, Merchant-of-Record services, invoices, and tax handling.

Do not use RevenueCat Billing itself for Indian checkout until RevenueCat removes the documented India limitation.

### Android alternative billing later

Dodo remains a possible second checkout option, not a replacement for RevenueCat or Google Play Billing.

---

## 12. Required Pre-Launch Gates

Before enabling real purchases:

- enroll PSRS in Apple and Google organization programs;
- obtain or verify PSRS D-U-N-S data;
- establish company-controlled account emails;
- configure Apple and Google products;
- bind RevenueCat customer identity to the CoverWise principal;
- implement RevenueCat webhooks;
- make server entitlements authoritative;
- implement exact-once usage grants and consumption;
- use localized store prices;
- implement restore, cancellation, refund, grace, renewal, and deletion flows;
- correct Privacy Policy and Terms for payment metadata and auto-renewal;
- complete sandbox lifecycle tests;
- verify Indian tax/accounting treatment with a qualified professional.

---

## 13. Anything Else?

### RevenueCat is not the payment processor

RevenueCat does not replace the banking and tax onboarding required by Apple or Google. Store payouts still require payment and tax setup in the store portals.

### A company is recommended, not universally mandatory

- RevenueCat account: no company required;
- Apple individual account: company not required, personal seller name shown;
- Google personal account: can monetize;
- organization accounts: legal entity and D-U-N-S required;
- CoverWise production recommendation: use PSRS.

### Dodo’s Indian payment strength is primarily web checkout

UPI and Merchant-of-Record support are valuable, but do not override native-store policy.

### Provider choice does not remove CoverWise’s backend responsibility

Whether the transaction originates from Apple, Google, or Dodo, CoverWise still needs one authoritative financial ledger and entitlement model.

---

## 14. Official Sources Checked

- RevenueCat, “Setting up RevenueCat”: https://www.revenuecat.com/docs/welcome/set-up-revenuecat
- RevenueCat, “Payments from Stores and Country Availability”: https://www.revenuecat.com/docs/platform-resources/developer-store-payments
- RevenueCat, “RevenueCat Billing”: https://www.revenuecat.com/docs/web/web-billing/configuring-overview
- RevenueCat, “Getting Started With RevenueCat Web”: https://www.revenuecat.com/docs/web/overview
- Apple, “Become a member”: https://developer.apple.com/programs/enroll/
- Apple, “Program enrollment”: https://developer.apple.com/help/account/membership/program-enrollment/
- Apple, “D-U-N-S Number”: https://developer.apple.com/help/account/membership/D-U-N-S/
- Google Play, “Choose a developer account type”: https://support.google.com/googleplay/android-developer/answer/13634885
- Google Play, “Changes to billing requirements for developers serving users in India”: https://support.google.com/googleplay/android-developer/answer/13306652
- Google Play, “Service fees”: https://support.google.com/googleplay/android-developer/answer/112622
- Dodo Payments, “Selling Digital Goods on iOS”: https://docs.dodopayments.com/features/appstore-digital-goods
- Dodo Payments, “India Payment Methods”: https://docs.dodopayments.com/features/payment-methods/india
- Dodo Payments, “Payment Methods”: https://docs.dodopayments.com/features/payment-methods
