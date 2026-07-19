/// Validates that a string is a plausible date in common formats:
/// DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, or DD.MM.YYYY.
/// Accepts 1 or 2-digit day/month and 2 or 4-digit year.
///
/// For ambiguous cases (both parts ≤ 12), assumes DD/MM/YYYY
/// (Indian convention for this insurance app).
bool isValidDate(String value) {
  final trimmed = value.trim();
  final dateRegex = RegExp(
    r'^(0?[1-9]|[12]\d|3[01])[/\-\.](0?[1-9]|1[0-2])[/\-\.]\d{2,4}$'
    r'|^(0?[1-9]|1[0-2])[/\-\.](0?[1-9]|[12]\d|3[01])[/\-\.]\d{2,4}$',
  );
  if (!dateRegex.hasMatch(trimmed)) return false;
  final parts = trimmed.split(RegExp(r'[/\-\.]'));
  if (parts.length != 3) return false;
  int day, month, year;
  final first = int.tryParse(parts[0]) ?? 0;
  final second = int.tryParse(parts[1]) ?? 0;
  if (first > 12 && second <= 12) {
    day = first; month = second;
  } else if (second > 12 && first <= 12) {
    month = first; day = second;
  } else {
    // Ambiguous — assume DD/MM/YYYY (Indian convention)
    day = first; month = second;
  }
  year = int.tryParse(parts[2]) ?? 0;
  if (year < 100) year += 2000;
  try {
    final dt = DateTime(year, month, day);
    return dt.month == month && dt.day == day;
  } catch (_) {
    return false;
  }
}
