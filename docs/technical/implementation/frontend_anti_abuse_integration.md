# Flutter Frontend Anti-Abuse System Integration

## Overview

The Flutter mobile app has been fully integrated with the Phase 1 anti-abuse system, providing a seamless user experience while enforcing rate limits and collecting lead information for business purposes.

## Key Features Implemented

### 1. Session Management
- **SessionService**: UUID-based session tracking with 24-hour expiration
- Persistent session storage using SharedPreferences
- Automatic session renewal when expired
- Session ID included in all API requests via `X-Session-ID` header

### 2. Lead Capture System
- **LeadCaptureDialog**: Optional contact information collection
- **ContactService**: Persistent storage of user preferences
- Email validation with disposable domain detection
- Phone number validation with international format support
- "Save for future" option to remember contact details

### 3. Rate Limiting Integration
- **RateLimitDialog**: User-friendly rate limit notifications
- Graceful handling of 429 HTTP status codes
- Clear messaging about upload limits and retry times
- Visual indicators for approaching limits

### 4. Usage Monitoring
- **UsageStatsWidget**: Real-time quota display
- Session-based and IP-based limit tracking
- Progress bars and status indicators
- Automatic refresh capabilities

### 5. Enhanced Error Handling
- Offline mode fallback when backend unavailable
- Network connectivity detection
- Graceful degradation of features
- User-friendly error messages

## Technical Implementation

### Session Management (`SessionService`)

```dart
class SessionService {
  static Future<String> getSessionId() async {
    // Returns existing session or creates new one
    // Sessions expire after 24 hours
  }
  
  static Future<String> createNewSession() async {
    // Force creates new session (for testing/reset)
  }
  
  static Future<bool> isSessionExpired() async {
    // Checks if current session is expired
  }
}
```

### API Service Updates

All API calls now include session headers:

```dart
// Upload with lead capture
Future<Map<String, dynamic>> uploadFile(File file, {String? email, String? phone}) async {
  final sessionId = await SessionService.getSessionId();
  
  final response = await _dio.post(
    '/documents/upload',
    data: formData,
    options: Options(
      headers: {'X-Session-ID': sessionId},
    ),
  );
}

// Query with session tracking
Future<Map<String, dynamic>> queryDocument(String query, {String? documentId}) async {
  final sessionId = await SessionService.getSessionId();
  
  final response = await _dio.post(
    '/query',
    data: data,
    options: Options(
      headers: {'X-Session-ID': sessionId},
    ),
  );
}
```

### Lead Capture Workflow

1. User selects document for upload
2. System checks for saved contact information
3. LeadCaptureDialog appears with pre-filled data (if available)
4. User can:
   - Provide email/phone (optional)
   - Skip contact collection
   - Save information for future uploads
5. Upload proceeds with contact data attached

### Rate Limit Handling

```dart
// In upload method
if (result['error'] == 'rate_limit_exceeded') {
  await showDialog(
    context: context,
    builder: (context) => RateLimitDialog(
      message: result['message'] ?? 'Upload limit exceeded',
      retryAfter: result['retry_after'],
    ),
  );
  return;
}
```

### Usage Stats Display

The UsageStatsWidget shows:
- Remaining uploads for the day
- Session usage vs. limits
- IP usage vs. limits
- Visual progress indicators
- Warning messages when approaching limits

## User Experience Flow

### Normal Upload Flow
1. User opens Documents screen
2. Usage stats displayed at top showing remaining quota
3. User selects "Upload Document"
4. File picker opens
5. After file selection, lead capture dialog appears
6. User provides contact info (optional) or skips
7. Upload proceeds with anti-abuse checks
8. Success message shown with offline/online indicator

### Rate Limited Flow
1. User attempts upload when limit reached
2. Rate limit dialog appears with clear explanation
3. Shows retry time in user-friendly format
4. Usage stats updated to reflect limit status
5. Upload button disabled until limit resets

### Offline Mode Flow
1. Backend unavailable or network issues
2. App falls back to local storage
3. Orange notification indicates offline mode
4. Full functionality maintained locally
5. Sync occurs when connectivity restored

## Configuration

### Rate Limits (Configurable via Backend)
- Session limit: 5 uploads per day (default)
- IP limit: 10 uploads per day (default)
- Limits reset at midnight UTC

### Session Settings
- Session duration: 24 hours
- Auto-renewal: Yes
- Storage: SharedPreferences (persistent)

### Contact Information
- Email validation: RFC compliant + disposable domain check
- Phone validation: International format support
- Storage: Optional, user-controlled
- Retention: Until user clears or disables

## Error Handling

### Network Errors
- Connection timeout: Graceful fallback to offline mode
- Server errors: User-friendly messages with retry options
- Rate limits: Clear explanation with retry timing

### Validation Errors
- Invalid email: Real-time validation with helpful messages
- Disposable email: Blocked with explanation
- Invalid phone: Format guidance provided

### Storage Errors
- Local storage full: Automatic cleanup of oldest documents
- Permissions: Clear instructions for user action

## Security Considerations

### Data Protection
- Contact information encrypted in local storage
- Session IDs are UUIDs (non-predictable)
- No sensitive data in logs or error messages

### Anti-Abuse Measures
- Client-side validation mirrors server-side rules
- Session tracking prevents circumvention
- Disposable email detection reduces fake leads

### Privacy
- Contact information collection is optional
- Clear consent for data storage
- Easy opt-out and data clearing

## Testing

### Unit Tests
- Session management functionality
- Contact service operations
- Validation logic
- Error handling scenarios

### Integration Tests
- End-to-end upload flow
- Rate limiting behavior
- Offline mode functionality
- Lead capture workflow

### User Acceptance Tests
- Upload quota visibility
- Rate limit messaging clarity
- Contact form usability
- Error message comprehension

## Deployment Notes

### Dependencies Added
- No new external dependencies required
- Uses existing packages: `uuid`, `shared_preferences`, `dio`

### Configuration Changes
- Backend URL updated to AWS App Runner
- Session management enabled by default
- Usage stats endpoint integrated

### Migration Considerations
- Existing users get new session on first app launch
- No data migration required
- Backward compatible with older backend versions

## Monitoring and Analytics

### Metrics Tracked
- Session creation and expiration rates
- Lead capture conversion rates
- Rate limit hit frequency
- Offline mode usage patterns

### User Behavior Insights
- Upload patterns and timing
- Contact information provision rates
- Feature usage statistics
- Error occurrence frequency

## Future Enhancements (Phase 2)

### Planned Features
- Policy-based fingerprinting using extracted data
- Enhanced OCR data validation
- Name/email cross-validation
- Behavioral pattern detection
- Advanced usage analytics

### Technical Improvements
- Background sync for offline uploads
- Push notifications for quota resets
- Advanced caching strategies
- Performance optimizations

## Conclusion

The Flutter frontend now provides a complete anti-abuse system integration that:
- Protects backend resources from overuse
- Collects valuable lead information for business growth
- Maintains excellent user experience
- Provides clear feedback and guidance
- Handles edge cases gracefully
- Supports both online and offline operation

This implementation serves as the foundation for Phase 2 enhancements while delivering immediate value for both users and the business. 