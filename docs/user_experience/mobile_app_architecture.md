# Mobile App Architecture (Flutter, Mobile-First)

## Overview
This document describes the architecture, flows, and integration points for the mobile-first Flutter app for the Insurance Policy Parser & QA platform. The app is designed for Indian insurance users, with robust support for family management, policy upload, and natural language QA.

---

## High-Level Architecture

```
+-------------------+         +-------------------+         +-------------------+
|   Flutter Mobile  | <-----> |   Firebase Auth   | <-----> |   Backend API     |
|   App (Android/iOS)|        | (email, phone,   |         | (FastAPI: user,   |
|                   |         |  Google login)   |         |  family, policy,  |
|                   |         |                   |         |  doc, QA, notif)  |
+-------------------+         +-------------------+         +-------------------+
```

- **Flutter App:** Handles all user interaction, PDF upload, QA, and notifications.
- **Firebase Auth:** Provides secure authentication (email, phone/OTP, Google login).
- **Backend API:** Manages user/family data, policy storage, document processing, RAG/QA, and notifications.

---

## Key User Flows

1. **Onboarding**
   - Welcome, explain features, privacy, and get started.
2. **Authentication**
   - Sign up/login via email, phone/OTP, or Google (Firebase Auth).
3. **User Profile & Family Management**
   - View/edit user info, add/remove family members (name, relationship, DOB).
4. **Policy Upload**
   - Upload PDF from device, assign to self or family member.
   - View list of uploaded policies.
5. **Policy QA**
   - Ask free-form questions about any policy.
   - View answers, source context, and policy details.
6. **Notifications**
   - Receive push notifications for renewals, payments, and important events (via Firebase Cloud Messaging).

---

## Integration Points
- **Firebase Auth:**
  - Handles all authentication flows; app receives ID token and passes it to backend for verification.
- **Backend API:**
  - All user, family, policy, and QA data is managed via RESTful endpoints.
  - PDF files are uploaded to backend (or directly to cloud storage if needed).
- **Firebase Cloud Messaging:**
  - Used for push notifications/reminders.

---

## Main Flutter Packages/Plugins
- `firebase_auth` (Firebase Auth integration)
- `cloud_firestore` (if any direct Firestore usage)
- `firebase_messaging` (push notifications)
- `http` (backend API calls)
- `file_picker` or `image_picker` (PDF upload)
- `pdf_viewer_plugin` or `syncfusion_flutter_pdfviewer` (PDF viewing)
- `provider` or `riverpod` (state management)
- `intl` (date formatting)

---

## Initial Screens & Features
- Onboarding/Welcome
- Login/Signup (email, phone/OTP, Google)
- User Profile
- Family Member Management
- Policy List & Upload
- Policy Details & PDF Viewer
- QA Chat/Question Interface
- Notifications/Reminders

---

## Documentation Principles
- This doc is always kept up to date as features/screens are added or changed.
- No full code is included—only flows, diagrams, and integration notes.
- API usage is documented with example requests/responses, not full implementation.

---

**See also:**
- [Comprehensive Architecture](../technical/unified_architecture/comprehensive_architecture.md)
- [API Documentation](../reference/api_documentation/)
- [Modern Stack Overview](../technical/modern_stack_overview.md) 