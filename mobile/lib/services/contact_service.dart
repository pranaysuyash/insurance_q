import 'package:hive/hive.dart';
import 'app_state_store.dart';

class ContactService {
  /// Get saved email address
  static Future<String?> getSavedEmail() async {
    final box = Hive.box(AppStateStore.boxName);
    final saveEnabled = box.get(AppStateStore.saveContactKey) as bool? ?? false;
    
    if (saveEnabled) {
      return box.get(AppStateStore.emailKey) as String?;
    }
    
    return null;
  }

  /// Get saved phone number
  static Future<String?> getSavedPhone() async {
    final box = Hive.box(AppStateStore.boxName);
    final saveEnabled = box.get(AppStateStore.saveContactKey) as bool? ?? false;
    
    if (saveEnabled) {
      return box.get(AppStateStore.phoneKey) as String?;
    }
    
    return null;
  }

  /// Save contact information
  static Future<void> saveContact({
    String? email,
    String? phone,
    required bool saveForFuture,
  }) async {
    final box = Hive.box(AppStateStore.boxName);
    
    await box.put(AppStateStore.saveContactKey, saveForFuture);
    
    if (saveForFuture) {
      if (email != null) {
        await box.put(AppStateStore.emailKey, email);
      }
      if (phone != null) {
        await box.put(AppStateStore.phoneKey, phone);
      }
    } else {
      // Clear saved contact info if user doesn't want to save
      await box.delete(AppStateStore.emailKey);
      await box.delete(AppStateStore.phoneKey);
    }
  }

  /// Clear all saved contact information
  static Future<void> clearSavedContact() async {
    final box = Hive.box(AppStateStore.boxName);
    await box.delete(AppStateStore.emailKey);
    await box.delete(AppStateStore.phoneKey);
    await box.put(AppStateStore.saveContactKey, false);
  }

  /// Check if contact saving is enabled
  static Future<bool> isSaveContactEnabled() async {
    final box = Hive.box(AppStateStore.boxName);
    return box.get(AppStateStore.saveContactKey) as bool? ?? false;
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
