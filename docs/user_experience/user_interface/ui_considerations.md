# UI/UX Considerations for Insurance Policy Parser & QA

This document outlines User Interface (UI) and User Experience (UX) considerations for the application.

## General Principles

*   **Clarity:** The interface should be clean, intuitive, and easy to understand.
*   **Efficiency:** Users should be able to complete tasks (uploading, querying) with minimal friction.
*   **Feedback:** Provide clear feedback to the user about system status (e.g., loading states, success messages, error messages).
*   **Responsiveness:** The UI should be responsive and adapt well to different screen sizes (especially for web and mobile).

## Key Screens/Views

### 1. Document Upload Area (Web & Mobile)

*   **Input Method:**
    *   Clear call-to-action button (e.g., "Upload Document", "Select File").
    *   Support for drag-and-drop (web).
    *   For mobile, access to device file system and camera for image capture.
*   **Feedback:**
    *   Display selected filename before processing.
    *   Show a progress indicator (e.g., progress bar or spinner) during upload and processing.
    *   Clear success or error messages post-processing.
*   **Constraints:**
    *   Clearly state supported file types (e.g., PDF, JPG, PNG).
    *   Indicate any file size limits if applicable.

### 2. Document View / Results Display

This is where the extracted information from the OCR service is presented.

*   **Full Text Display:**
    *   A scrollable area to show the entire extracted text (`full_text`).
    *   Consider options for text formatting if it improves readability (though raw text is often safest initially).
    *   Option to copy text.
*   **Layout Elements Display (`layout_elements`)**:
    *   The `layout_elements` are a list of dictionaries, typically `{"question": str, "answer": str, "score": float, "box_2d": list}`.
    *   **Presentation Ideas:**
        *   **Q&A List:** Display as a structured list of questions and their corresponding answers. Highlight the answer.
            *Example:*
            ```
            -----------------------------------------------------
            Question: What is the policy number?
            Answer:   POL12345678
            Confidence: 0.92
            -----------------------------------------------------
            Question: Who is the primary insured?
            Answer:   John Doe
            Confidence: 0.88
            -----------------------------------------------------
            ```
        *   **Card-based View:** Each layout element (Q&A pair) could be a card.
        *   **(Advanced) Interactive Document View:** If displaying the original document image(s), potentially highlight the bounding boxes (`box_2d`) associated with each answer when the user hovers over or clicks a layout element. This is more complex but offers excellent UX.
*   **Metadata Display:**
    *   Show basic document metadata (filename, processing date, page count if applicable).

### 3. Question Answering (RAG) Interface

*   **Input:**
    *   Clear text input field for the user's question.
    *   A prominent "Ask" or "Submit" button.
*   **Output/Results:**
    *   Display the LLM-generated answer clearly.
    *   **Source Attribution:** If the RAG service provides source information (e.g., specific text chunks, document ID, page number), display these alongside the answer. This helps build trust and allows users to verify information.
        *   Example: "Answer: ... (Source: Document A, Page 3, Block 5)"
        *   Could be clickable to highlight or show the source text chunk.
*   **Interaction:**
    *   Maintain a history of questions and answers for the current session if feasible.
    *   Loading indicator while the RAG pipeline processes the query.

## Error Handling & User Feedback

*   **API Errors:** If backend API calls (Hugging Face, OpenAI) fail, provide user-friendly error messages instead of raw technical errors. E.g., "Could not process document, please try again later." or "Unable to answer question at this time."
*   **Validation Errors:** Guide users if their input is invalid (e.g., unsupported file type).
*   **No Results:** If RAG finds no relevant context, provide a clear message like "I could not find an answer to your question in the provided documents."

## Mobile-Specific Considerations (Flutter)

*   **Native Look and Feel:** Adhere to platform UI guidelines (Material Design for Android, Cupertino for iOS) where appropriate.
*   **Touch-Friendly Controls:** Ensure all interactive elements are easily tappable.
*   **Performance:** Optimize for smooth performance and responsiveness on mobile devices.
*   **Offline Support (Future):** Consider if any level of offline support would be beneficial (e.g., viewing previously processed documents if cached locally on the device - this is a more advanced feature).

## Accessibility (A11y)

*   Consider basic accessibility principles:
    *   Sufficient color contrast.
    *   Keyboard navigability (web).
    *   Screen reader compatibility (alt text for images, proper ARIA roles if using complex web components).

---
This document is a starting point and should be expanded as UI design and development progresses. 