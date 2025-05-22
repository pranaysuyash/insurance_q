# Insurance Policy Parser & QA App: User Guide

Welcome to the Insurance Policy Parser & QA App! This guide will help you understand how to use the application to manage and get insights from your insurance policies.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Uploading Insurance Policies](#uploading-insurance-policies)
4. [Viewing Your Policies](#viewing-your-policies)
5. [Asking Questions About Your Policies](#asking-questions-about-your-policies)
6. [Account Management (If Applicable)](#account-management-if-applicable)
7. [Troubleshooting](#troubleshooting)
8. [Privacy and Security](#privacy-and-security)
9. [Mobile App Specific Features](#mobile-app-specific-features)

## Introduction

The Insurance Policy Parser & QA App helps you manage and understand your insurance policies. You can:

- Upload your insurance policy documents (PDFs).
- View extracted text and information from your policies.
- Ask questions in natural language about your coverage and get answers.
- Securely store and access your policy information.

## Getting Started

### Accessing the App

- **Web Application:** Access via your web browser at the provided URL (e.g., `http://localhost:8080` during local development).
- **Mobile Application:** If you are using the Flutter mobile app, download and install it on your Android or iOS device.

### Creating an Account / Logging In

- Depending on the application setup, you might need to register an account or log in.
- If using Firebase authentication (common with the mobile app), you may have options like email/password, Google Sign-In, or phone authentication.
- Follow the on-screen prompts to sign up or log in.

## Uploading Insurance Policies

### Supported Document Types

- The system primarily supports PDF documents (text-based or scanned).
- Ensure documents are clear for best results if they are scans.

### Upload Process (Web Example)

1.  Navigate to the upload section of the web application.
2.  Select a PDF file from your device (e.g., using an "Upload Document" button).
3.  The system will process the document. This involves:
    *   **Text Extraction (OCR):** Converting your policy (especially if scanned) into machine-readable text.
    *   **Indexing:** Preparing the extracted text so you can ask questions about it.
4.  Processing time can vary based on document size and complexity.

### Upload Process (Mobile App)

- The mobile app will have a similar upload function, allowing you to select PDFs from your phone's storage.
- Follow the in-app instructions for uploading.

## Viewing Your Policies

- After successful upload and processing, your documents will typically be listed in a central place, like a dashboard or a document list.
- You should be able to see the original document filename.
- The application may display the extracted full text of the policy or key layout elements identified during processing.

## Asking Questions About Your Policies

This is a core feature of the app, powered by a Retrieval-Augmented Generation (RAG) system.

### How to Ask

1.  Find the Q&A section in the application (web or mobile).
2.  Select the document you want to ask about (if you have multiple).
3.  Type your question in plain language into the input field (e.g., "What is my deductible for surgery?").
4.  Submit your query.

### Understanding Answers

The system will provide an answer based on the content of your policy document. The answer may include:

- A direct response to your question.
- Snippets of text from your policy that support the answer (sources).

### Example Questions

- "What is my annual out-of-pocket maximum?"
- "Are emergency room visits covered?"
- "What are the exclusions listed in my policy?"
- "Is specific medication X covered under my plan?"

## Account Management (If Applicable)

- If the application requires user accounts (e.g., via Firebase on mobile, or a custom backend system):
    - You may have a profile section to manage your user details.
    - Options to change your password or log out.

## Troubleshooting

- **Upload Issues:**
    - Ensure your document is a PDF and not corrupted.
    - For scanned documents, make sure the quality is good.
    - Check your internet connection.
- **Q&A Issues:**
    - If answers seem irrelevant, try rephrasing your question to be more specific.
    - Ensure you have selected the correct document if you have multiple uploaded.
- **General App Issues (Web):**
    - Try refreshing the page.
    - Clear your browser cache and cookies for the site.
- **General App Issues (Mobile):**
    - Ensure the app is updated to the latest version.
    - Try restarting the app.
    - Check your device's internet connection.

## Privacy and Security

- The application aims to handle your policy documents securely.
- Refer to any provided Privacy Policy or Terms of Service for details on how your data is managed, especially regarding document storage, processing by AI models (like OpenAI or Hugging Face), and data retention.

## Mobile App Specific Features

The Flutter mobile app provides a rich, user-friendly interface with several enhanced features:

### Dashboard

The dashboard serves as the main landing page and provides:

- **Welcome Card**: Shows how many documents you have in your library
- **Documents by Type**: Visual representation of your insurance documents by category (health, auto, home, life, etc.)
- **Quick Actions**: One-tap access to common functions:
  - Upload Document: Add a new insurance policy
  - Ask a Question: Navigate to the Q&A interface
  - Compare Policies: (Coming soon) Compare coverage between different policies
  - Insurance Terms: Access the glossary of insurance terminology

- **Recent Activities**: Timeline of your recent document uploads and questions
- **Insurance Terminology**: Quick reference for common insurance terms with a "View All" option for a comprehensive glossary

### Document Management

The document management screen provides these capabilities:

1. **Upload Process**:
   - Tap "Upload Document" from the dashboard or the Documents screen
   - Select a document from your device storage
   - The app will display an upload progress indicator
   - Once complete, you'll see extraction results and document metadata

2. **Document List**:
   - All your uploaded documents are displayed in a scrollable list
   - Each document shows its type, upload date, and a preview icon
   - Tap a document to expand and see more details
   - Options to delete documents or ask questions about them

### Enhanced Q&A Interface

The Q&A screen has been redesigned with three tabs for better organization:

1. **Standard Questions Tab**:
   - Pre-set questions organized by categories:
     - Policy Basics (policy number, start/end dates, insurer, etc.)
     - Coverage Details (total coverage, deductible, out-of-pocket maximum)
     - Premiums & Payments (premium amount, payment schedule)
     - Claims (filing process, documentation needed)
     - Exclusions & Limitations (what's not covered, waiting periods)
     - Benefits (dental, vision, mental health coverage)
   - Tap any question to instantly get an answer for your selected document

2. **Custom Question Tab**:
   - Ask your own questions in natural language
   - Type questions in a multi-line text field
   - View answers with source information from your policy
   - Scrollable answer cards with copy and share options

3. **History Tab**:
   - Keeps track of all your previous questions and answers
   - Tap any item to view the full answer again

### Document Selection

- At the top of the Q&A screen, you'll find a document selector
- This allows you to specify which policy you want to ask questions about
- The app remembers your last selected document for convenience

### Insurance Terminology Glossary

- Access via the "Insurance Terms" quick action or "View All" link on the dashboard
- Comprehensive alphabetically-organized list of insurance terms and definitions
- Scrollable interface for easy browsing
- Search functionality for finding specific terms quickly

This guide provides a general overview. The exact look and feel and specific steps might vary slightly between the web and mobile versions of the application.
