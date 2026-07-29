/// Pure validation rules for user-provided contact details.
///
/// This keeps contact policy independent from build-time configuration so the
/// same rules can be used by forms, services, and release validation.
class ContactValidator {
  static const Set<String> _disposableEmailDomains = {
    '10minutemail.com',
    'tempmail.org',
    'guerrillamail.com',
    'mailinator.com',
    'throwaway.email',
    'temp-mail.org',
    'yopmail.com',
    'maildrop.cc',
    'sharklasers.com',
    'getairmail.com',
    'dispostable.com',
    'tempail.com',
    'temp-mail.io',
    'mohmal.com',
    'emailondeck.com',
    'fakeinbox.com',
    'trashmail.com',
    'getnada.com',
    'tempinbox.com',
    'guerrillamailblock.com',
    'spam4.me',
    'mailnesia.com',
    'trbvm.com',
    'incognitomail.org',
    'anonymbox.com',
    'mintemail.com',
  };

  static bool isDisposableEmail(String email) {
    final domain = email.split('@').last.toLowerCase();
    return _disposableEmailDomains.contains(domain);
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email) && !isDisposableEmail(email);
  }

  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    return phoneRegex.hasMatch(phone);
  }
}
