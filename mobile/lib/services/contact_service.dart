import 'package:shared_preferences/shared_preferences.dart';

class ContactService {
  static const String _emailKey = 'saved_email';
  static const String _phoneKey = 'saved_phone';
  static const String _saveContactKey = 'save_contact_enabled';

  /// Get saved email address
  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saveEnabled = prefs.getBool(_saveContactKey) ?? false;
    
    if (saveEnabled) {
      return prefs.getString(_emailKey);
    }
    
    return null;
  }

  /// Get saved phone number
  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saveEnabled = prefs.getBool(_saveContactKey) ?? false;
    
    if (saveEnabled) {
      return prefs.getString(_phoneKey);
    }
    
    return null;
  }

  /// Save contact information
  static Future<void> saveContact({
    String? email,
    String? phone,
    required bool saveForFuture,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_saveContactKey, saveForFuture);
    
    if (saveForFuture) {
      if (email != null) {
        await prefs.setString(_emailKey, email);
      }
      if (phone != null) {
        await prefs.setString(_phoneKey, phone);
      }
    } else {
      // Clear saved contact info if user doesn't want to save
      await prefs.remove(_emailKey);
      await prefs.remove(_phoneKey);
    }
  }

  /// Clear all saved contact information
  static Future<void> clearSavedContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_phoneKey);
    await prefs.setBool(_saveContactKey, false);
  }

  /// Check if contact saving is enabled
  static Future<bool> isSaveContactEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_saveContactKey) ?? false;
  }

  /// Get both saved email and phone
  static Future<Map<String, String?>> getSavedContact() async {
    final email = await getSavedEmail();
    final phone = await getSavedPhone();
    
    return {
      'email': email,
      'phone': phone,
    };
  }
} 