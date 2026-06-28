class AppFormatters {
  static String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String date(DateTime date) {
    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year}';
  }

  static String time(DateTime date) {
    return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  static String dateTime(DateTime date) {
    return '${AppFormatters.date(date)} ${AppFormatters.time(date)}';
  }

  static String amount(double amount) {
    return '${amount.toStringAsFixed(2)} zł';
  }
}