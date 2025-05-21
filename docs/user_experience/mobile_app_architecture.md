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
   - Limited to 3-5 free uploads before agent connection prompt.
5. **Policy QA**
   - Ask free-form questions about any policy.
   - View answers, source context, and policy details.
6. **Policy Comparison**
   - Compare coverage, terms, and costs between multiple policies.
   - Highlight differences in key areas.
7. **History & Timeline**
   - View chronological history of uploads and QA interactions.
   - Track policy changes and important dates.
8. **Notifications**
   - Receive push notifications for renewals, payments, and important events (via Firebase Cloud Messaging).

---

## Lead Generation Strategy

The app implements a freemium model designed to generate quality insurance leads:

1. **Free Tier Limitations:**
   - Users can upload and analyze up to 3-5 insurance documents for free.
   - All QA features are available for these documents.
   - Basic policy comparison is available.

2. **Agent Connection Prompt:**
   - When a user reaches the document upload limit, they receive a prompt to connect with an insurance agent.
   - Options include scheduling a call, requesting a callback, or chatting with an agent.
   - The prompt highlights the benefits of professional insurance advice.

3. **Agent Matching:**
   - Users are matched with agents based on:
     - Geographic location
     - Types of insurance analyzed
     - Family composition
     - Specific needs identified through QA interactions

4. **Premium Features Teaser:**
   - Preview of advanced features available after agent consultation.
   - Potential for exclusive offers/discounts on new policies.

5. **Analytics:**
   - Track conversion rates from free users to agent connections.
   - Identify which insurance types and user questions lead to highest conversion.

---

## Integration Points
- **Firebase Auth:**
  - Handles all authentication flows; app receives ID token and passes it to backend for verification.
- **Backend API:**
  - All user, family, policy, and QA data is managed via RESTful endpoints.
  - PDF files are uploaded to backend (or directly to cloud storage if needed).
- **Firebase Cloud Messaging:**
  - Used for push notifications/reminders.
- **CRM Integration:**
  - Agent connection requests are sent to CRM system for follow-up.

---

## Comprehensive Screen Plan

### 1. Onboarding & Authentication
- Welcome/intro carousel
- Login screen (email, phone/OTP, Google)
- Registration form
- Password recovery
- Authentication verification

### 2. Dashboard/Home
- User profile summary
- Family members overview
- Policy summary cards
- Recent activity timeline
- Quick action buttons
- Upcoming renewal alerts

### 3. User & Family Management
- Profile edit form
- Family member list
- Add/edit family member details
- Relationship selection
- Policy assignment controls

### 4. Document Upload & Management
- File source selection UI
- Camera document capture
- Upload progress indicator
- Document type selection
- Family member assignment
- Upload limit counter and alerts

### 5. Document List
- Grid/list view with filters
- Sort controls
- Search functionality
- Status indicators
- Quick action buttons
- Batch operations

### 6. Document View
- PDF viewer with navigation
- Extracted sections cards
- Metadata display
- Edit mode for corrections
- Share functionality

### 7. QA Interface
- Policy selector
- Question input with suggestions
- Voice input option
- Answer display with sources
- Conversation history
- Bookmark/save options

### 8. Policy Comparison
- Policy selection interface
- Comparison category tabs
- Side-by-side view
- Difference highlighting
- Summary section
- Export/share functions

### 9. History & Timeline
- Chronological activity display
- Filter by activity type
- Family member grouping
- Calendar alternative view
- Search function

### 10. Notifications Center
- Notification list with filters
- Status indicators
- Quick actions
- Settings access
- Read/unread status

### 11. Agent Connection
- Connect request form
- Agent profiles
- Scheduling calendar
- Communication preferences
- Request status tracking

### 12. Settings
- Theme options
- Notification preferences
- Data storage controls
- Privacy settings
- Account management

---

## Main Flutter Packages/Plugins
- `firebase_auth` (Firebase Auth integration)
- `cloud_firestore` (if any direct Firestore usage)
- `firebase_messaging` (push notifications)
- `http` (backend API calls)
- `file_picker` or `image_picker` (PDF upload)
- `pdf_viewer_plugin` or `syncfusion_flutter_pdfviewer` (PDF viewing)
- `provider` or `riverpod` (state management)
- `flutter_bloc` (for complex state management)
- `intl` (date formatting and localization)
- `shared_preferences` (local settings storage)
- `sqflite` or `hive` (local database for offline access)
- `flutter_local_notifications` (notification management)
- `path_provider` (file system access)
- `camera` (document capture)
- `charts_flutter` (data visualization)
- `url_launcher` (external links and calls)

---

## Navigation Structure
- **Bottom Navigation:**
  - Home/Dashboard
  - Documents
  - QA Interface
  - Family
  - More Menu

- **App Drawer/More Menu:**
  - Profile
  - Policy Comparison
  - History/Timeline
  - Notifications
  - Connect with Agent
  - Settings
  - Help & Support

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