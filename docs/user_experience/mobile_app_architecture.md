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

## Implementation Status & TODOs

### Current Status
- Flutter project scaffolded in `mobile/` directory
- Latest dependencies added: Riverpod, Dio, PDFx, Firebase, Hive, etc.
- Modern folder structure created
- `main.dart` with Material 3, Riverpod, and bottom navigation
- Stubs for all main screens (Home, Documents, QA, Family, More)

### Next Steps / TODOs
- [ ] Set up environment config for backend API endpoints (dev/prod)
- [ ] Implement health check screen to verify backend connectivity
- [ ] Scaffold document upload UI and integrate with `/upload` endpoint
- [ ] Scaffold QA interface (question input, call `/query`, show answer)
- [ ] Add error handling and loading indicators for API calls
- [ ] Implement user authentication (Firebase Auth integration)
- [ ] Add family management UI and backend integration
- [ ] Implement document list and detail views (PDF viewer, extracted sections)
- [ ] Add policy comparison UI and logic
- [ ] Implement notifications (Firebase Messaging, local notifications)
- [ ] Add settings, theming, and preferences screens
- [ ] Write widget/unit tests for core features
- [ ] Update documentation as features are built

---

**To test the current app:**
1. `cd mobile`
2. `flutter run` (on emulator or device)
3. You'll see navigation and screen stubs; backend integration coming next.

**See also:**
- [Comprehensive Architecture](../technical/unified_architecture/comprehensive_architecture.md)
- [API Documentation](../reference/api_documentation/)
- [Modern Stack Overview](../technical/modern_stack_overview.md)

---

## QA Experience Design

### 1. Common Questions on Main Page
- Display a horizontal or grid list of "Common Questions" (e.g., "What is my policy number?", "What is the coverage amount?", "When does my policy expire?").
- Tapping a question instantly sends it to the backend and displays the answer.
- These questions can be dynamic (fetched from backend) or static (hardcoded for now).

### 2. Ask Questions as Chat
- Below the common questions, have a "Chat with PolicyBot" section.
- This is a chat-style interface:
  - User types a question (or selects from suggestions).
  - The conversation appears as a chat thread (user messages on right, bot answers on left).
  - Each answer can show sources/citations.
  - Option to "bookmark" or "copy" an answer.

### 3. Upload Limit Enforcement
- Track the number of documents uploaded by the user.
- If the user tries to upload more than 3 (or 5), show a modal or banner:
  - "You've reached your free upload limit! Connect with an insurance expert to unlock more features."
  - Provide options: "Schedule a call", "Chat with agent", "Request callback".

### 4. Optional Enhancements
- Show a "Recent Questions" section for quick repeat queries.
- Allow voice input for questions (using `speech_to_text` package).
- Show a "Why talk to an agent?" info section after the limit is reached.

### Implementation Plan
1. Add a `common_questions.dart` widget for the main page.
2. Create a `qa_chat_screen.dart` with chat UI and backend integration.
3. Implement upload limit logic (can be tracked locally or via backend).
4. Show agent prompt modal/banner when limit is reached.

### Example UI Flow
- **Home Screen:**
  - [Common Questions Grid]
  - ["Ask PolicyBot" Chat Button]
  - [Recent Questions List]
- **QA Chat Screen:**
  - [Chat Thread]
  - [Input Field + Send Button]
  - [Upload Limit Banner/Modal if needed]

---

## Running and Testing the Flutter App with Backend (Wi-Fi, Real Device)

### 1. Prerequisites
- Backend (FastAPI, Docker Compose, etc.) is set up and working.
- Flutter app is scaffolded in `mobile/`.
- Android/iOS device and computer are on the same Wi-Fi network.
- Wireless debugging is set up (e.g., `adb pair` and `adb connect` for Android).

### 2. Find Your Computer's LAN IP Address
- On your computer, run:
  ```sh
  ifconfig | grep inet
  ```
  or (on Mac):
  ```sh
  ipconfig getifaddr en0
  ```
- Note the IP address that looks like `192.168.x.x` or `10.0.x.x`.

### 3. Configure the Backend to Listen on All Interfaces
- If using **Uvicorn/FastAPI** directly:
  ```sh
  uvicorn main:app --host 0.0.0.0 --port 8000
  ```
- If using **Docker Compose**, ensure your `docker-compose.yml` exposes port 8000 and the service is not bound to `localhost` only:
  ```yaml
  ports:
    - "8000:8000"
  ```
- **Restart** your backend services if you change any config.

### 4. Test Backend Accessibility from Your Device
- On your phone/tablet, open a browser and go to:
  ```
  http://<your-computer-ip>:8000/health
  ```
- You should see a JSON health response (e.g., `{"status": "healthy", ...}`).
- If not, check:
  - Firewall settings (allow incoming connections on port 8000).
  - Docker port mappings.
  - That your device and computer are on the same Wi-Fi.

### 5. Update Flutter App API Endpoint
- In `mobile/lib/services/api_service.dart`, set:
  ```dart
  static const String baseUrl = 'http://<your-computer-ip>:8000';
  ```
  Replace `<your-computer-ip>` with your actual LAN IP.

### 6. Run the Flutter App on Your Device
- In your terminal:
  ```sh
  cd /Users/pranay/Projects/medpiper/insurance_app/mobile
  flutter run
  ```
- Select your device (should show up as a wireless device).

### 7. Test the Document Upload & OCR Flow
- In the app, go to the **Documents** tab.
- Tap **"Select Document"** and pick a PDF or image file.
- Tap **"Upload & OCR"**.
- Wait for the upload and processing to complete.
- You should see:
  - The extracted text (truncated if long)
  - Any extracted sections (as cards)

### 8. Troubleshooting
- **Network error:** Double-check the IP and port, backend status, and firewall.
- **CORS or 500 error:** Check backend logs and test the `/upload` endpoint with Postman/cURL.
- **Emulator:** Use `10.0.2.2` for Android emulator, `localhost` for iOS simulator (if backend is on the same Mac).

### 9. Next Steps
- Once upload and OCR work, proceed to QA integration (ask questions about the uploaded document). 