/// Returns "day" or "days" based on the count.
String pluralizeDay(int count) => count == 1 ? 'day' : 'days';

/// Calculates remaining days in a challenge.
/// [totalDays] is the total challenge length (e.g. 75).
/// [currentDay] is the current day number (1-based).
int calculateRemainingDays(int totalDays, int currentDay) {
  return totalDays - currentDay;
}

/// Validates a task/challenge name.
/// Returns null if valid, or an error message string if invalid.
String? validateTaskName(String name) {
  final trimmed = name.trim();

  if (trimmed.isEmpty) {
    return 'Task name cannot be empty';
  }

  if (trimmed.length < 3) {
    return 'Task name must be at least 3 characters';
  }

  if (trimmed.length > 100) {
    return 'Task name must be 100 characters or less';
  }

  // Reject names that are only numbers
  if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
    return 'Task name cannot be only numbers';
  }

  // Reject names that are only special characters
  if (RegExp(r'^[^a-zA-Z0-9]+$').hasMatch(trimmed)) {
    return 'Task name must contain at least one letter or number';
  }

  // Reject names with no letters (e.g. "123!@#")
  if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
    return 'Task name must contain at least one letter';
  }

  return null; // Valid
}

/// Sanitizes user input for task names.
/// Trims whitespace and collapses multiple spaces.
String sanitizeTaskName(String input) {
  // Trim leading/trailing whitespace
  var result = input.trim();

  // Collapse multiple spaces into one
  result = result.replaceAll(RegExp(r'\s+'), ' ');

  return result;
}
