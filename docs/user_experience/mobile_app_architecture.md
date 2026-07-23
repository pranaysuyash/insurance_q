# Mobile App Architecture (Flutter, Mobile-First)

## Overview
This document describes the architecture, flows, and integration points for the mobile-first Flutter app for the Insurance Policy Parser & QA platform. The app is designed for Indian insurance users, with robust support for family management, policy upload, and natural language QA.

> **Implementation status note (2026-07-22):** this document includes historical notes from early
> product experiments. The active runtime authentication contract is now **Supabase Auth
> (email + Google + optional phone), with RLS-driven ownership in Postgres** as captured in
> [docs/architecture/coverwise_canonical_architecture.md](../architecture/coverwise_canonical_architecture.md).
> Firebase/Auth references here are retained as historical exploration unless explicitly flagged above.

---

## High-Level Architecture

```
+-------------------+         +-------------------------------+         +-------------------+
|   Flutter Mobile  | <-----> |   Supabase Auth               |         |   Backend API     |
|   App (Android/iOS)|        | (email, phone, Google, OAuth) |         | (FastAPI: user,   |
|                   |         |                               |         |  family, policy,  |
|                   |         |                               |         |  doc, QA, notif)  |
+-------------------+         +-------------------------------+         +-------------------+
```

- **Flutter App:** Handles all user interaction, PDF upload, QA, and notifications.
- **Auth:** Supabase Auth (managed production control plane). Firebase/Auth alternatives are retained as historical exploration unless explicitly reintroduced.
- **Backend API:** Manages user/family data, policy storage, document processing, RAG/QA, and notifications.

---

## Key User Flows

1. **Onboarding**
   - Welcome, explain features, privacy, and get started.
2. **Authentication**
   - Sign up/login via email, phone/OTP, or Google via Supabase Auth.
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
   - Receive push notifications for renewals, payments, and important events.
   - Notification delivery vendor is tracked as follow-up architecture, not part of the current auth/data contract.

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
- **Supabase Auth:**
  - Handles authentication flows; app receives session token and the API extracts the owner from the server-side Supabase token.
- **Backend API:**
  - All user, family, policy, and QA data is managed via RESTful endpoints.
  - PDF files are uploaded to backend (or directly to cloud storage if needed).
- **Push Notifications:**
  - Current runtime implementation tracks push notification delivery as a follow-up architecture item.
  - Historical notes mention Firebase Cloud Messaging, which is not the active product contract.
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
- `supabase_flutter` (Supabase Auth + client session support)
- `go_router` or `go_router_stateful` (navigation)
- `http` (backend API calls)
- `file_picker` or `image_picker` (PDF upload)
- `pdf_viewer_plugin` or `syncfusion_flutter_pdfviewer` (PDF viewing)
- `riverpod` (state management; see ADR-2026-07-22-02)
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

## Folder Structure & Code Organization
The Flutter app follows a standard clean architecture pattern:

```
mobile/
├── lib/
│   ├── main.dart                # App entry point, Material theme, providers
│   ├── models/                  # Data models (document_model.dart, qa_models.dart)
│   ├── providers/               # State management using Riverpod
│   │   ├── questions_provider.dart   # Manages Q&A state and history
│   │   ├── storage_provider.dart     # SharedPreferences and document storage
│   ├── screens/                 # UI screens
│   │   ├── dashboard_screen.dart     # Main dashboard with cards and actions
│   │   ├── documents_screen.dart     # Document upload and management
│   │   ├── documents_list.dart       # List of uploaded documents
│   │   ├── qa_screen.dart            # Q&A interface with tabs
│   │   ├── document_selection_dialog.dart # Document picker dialog
│   ├── services/                # Backend API and device services
│   │   ├── api_service.dart          # HTTP client for backend API
│   │   ├── local_storage_service.dart # Local document caching
│   ├── widgets/                 # Reusable UI components
```

---

## Implementation Status & TODOs

### Completed
- ✅ Flutter project scaffolded in `mobile/` directory with organized folder structure
- ✅ Latest dependencies added: Riverpod, Dio, PDFx, Supabase Flutter client, Hive, etc.
- ✅ Modern folder structure created with separation of concerns
- ✅ `main.dart` with Material 3, Riverpod, and bottom navigation
- ✅ Dashboard screen with document summary, quick actions, and terminology
- ✅ Documents screen with upload functionality and document list
- ✅ Q&A interface with standard questions, custom questions, and history tabs
- ✅ Fixed RenderFlex overflow issues in document cards
- ✅ Fixed keyboard overlap issues in Q&A screen
- ✅ Improved document terminology display with expanded definitions
- ✅ Enhanced navigation between screens with proper routing

### Next Steps / TODOs
- [ ] Add loading indicators for file uploads
- [ ] Improve error handling with user-friendly messages
- [ ] Add offline caching for Q&A results
- [ ] Complete the full auth lifecycle hardening on the active Supabase path (recovery, reset, sign-out, account deletion)
- [ ] Add family management UI and backend integration
- [ ] Implement document comparison feature
- [ ] Add document search functionality
- [ ] Optimize mobile layouts for different screen sizes
- [ ] Implement analytics tracking

---

## UI Components & Screens

### Dashboard Screen
The dashboard provides an overview of the user's insurance documents and quick access to key features:

- **Welcome Card**: Displays the number of documents and a welcome message
- **Documents by Type**: Horizontal scrollable cards showing document categories
- **Quick Actions**: Buttons for common tasks (Upload Document, Ask a Question, etc.)
- **Recent Activities**: List of recently uploaded documents and asked questions
- **Insurance Terminology**: Common insurance terms with definitions and a "View All" option that shows a comprehensive glossary

### Documents Screen
Allows users to upload and manage insurance documents:

- **Upload Area**: Provides file selection and upload with duplicate detection
- **Document List**: Shows all uploaded documents with metadata
- **Document Actions**: Options to view, delete, or ask questions about documents

### Q&A Screen
The Q&A interface is organized into three tabs:

- **Standard Questions**: Pre-defined questions organized by categories (Policy Basics, Coverage Details, etc.)
- **Custom Question**: Free-form question input with answer display
- **History**: Record of previously asked questions and answers

The screen also includes a document selector to specify which insurance document to query.

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
  cd mobile
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

### 8.1. Troubleshooting Common Android Build Issues

If you encounter build failures when running `flutter run` for Android, try the following steps. Remember to run `flutter clean` in your `mobile` directory after making changes to `build.gradle.kts` files.

1.  **Android NDK Version Mismatch:**
    *   **Error:** `Your project is configured with Android NDK X, but the following plugin(s) depend on a different Android NDK version: Y`
    *   **Fix:** Update the NDK version in `mobile/android/app/build.gradle.kts`:
        ```kotlin
        android {
            // ...
            ndkVersion = "27.0.12077973" // Or the version required by plugins
            // ...
        }
        ```

2.  **Core Library Desugaring Required:**
    *   **Error:** `Dependency ':some_plugin' requires core library desugaring to be enabled for :app.` or `Dependency ':some_plugin' requires desugar_jdk_libs version to be X or above for :app, which is currently Y`
    *   **Fix:** Enable core library desugaring in `mobile/android/app/build.gradle.kts`:
        ```kotlin
        android {
            // ...
            compileOptions {
                // ...
                isCoreLibraryDesugaringEnabled = true
            }
            // ...
        }

        dependencies {
            // ...
            coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // Ensure this version (or newer) meets plugin requirements
        }
        ```
        Check the error message for the specific `desugar_jdk_libs` version required by the problematic plugin and update accordingly.

3.  **minSdkVersion Too Low:**
    *   **Error:** `uses-sdk:minSdkVersion A cannot be smaller than version B declared in library [:some_plugin]`
    *   **Fix:** Increase the `minSdk` in `mobile/android/app/build.gradle.kts`. The error message or Flutter Fix will often suggest the required version (e.g., 23 for `firebase_auth`):
        ```kotlin
        android {
            // ...
            defaultConfig {
                // ...
                minSdk = 23 // Or the version required by plugins
                // ...
            }
            // ...
        }
        ```
        Note: Increasing `minSdk` means your app will not support Android versions below the new minimum.

### 9. Next Steps
- Once upload and OCR work, proceed to QA integration (ask questions about the uploaded document). 

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
  cd mobile
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

### 8.1. Troubleshooting Common Android Build Issues

If you encounter build failures when running `flutter run` for Android, try the following steps. Remember to run `flutter clean` in your `mobile` directory after making changes to `build.gradle.kts` files.

1.  **Android NDK Version Mismatch:**
    *   **Error:** `Your project is configured with Android NDK X, but the following plugin(s) depend on a different Android NDK version: Y`
    *   **Fix:** Update the NDK version in `mobile/android/app/build.gradle.kts`:
        ```kotlin
        android {
            // ...
            ndkVersion = "27.0.12077973" // Or the version required by plugins
            // ...
        }
        ```

2.  **Core Library Desugaring Required:**
    *   **Error:** `Dependency ':some_plugin' requires core library desugaring to be enabled for :app.` or `Dependency ':some_plugin' requires desugar_jdk_libs version to be X or above for :app, which is currently Y`
    *   **Fix:** Enable core library desugaring in `mobile/android/app/build.gradle.kts`:
        ```kotlin
        android {
            // ...
            compileOptions {
                // ...
                isCoreLibraryDesugaringEnabled = true
            }
            // ...
        }

        dependencies {
            // ...
            coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") // Ensure this version (or newer) meets plugin requirements
        }
        ```
        Check the error message for the specific `desugar_jdk_libs` version required by the problematic plugin and update accordingly.

3.  **minSdkVersion Too Low:**
    *   **Error:** `uses-sdk:minSdkVersion A cannot be smaller than version B declared in library [:some_plugin]`
    *   **Fix:** Increase the `minSdk` in `mobile/android/app/build.gradle.kts`. The error message or Flutter Fix will often suggest the required version (e.g., 23 for `firebase_auth`):
        ```kotlin
        android {
            // ...
            defaultConfig {
                // ...
                minSdk = 23 // Or the version required by plugins
                // ...
            }
            // ...
        }
        ```
        Note: Increasing `minSdk` means your app will not support Android versions below the new minimum.

### 9. Next Steps
- Once upload and OCR work, proceed to QA integration (ask questions about the uploaded document). 
