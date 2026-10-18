List<Map<String, dynamic>> unreadDeliveredNotifications(
  Iterable<Map<String, dynamic>> notifications,
) =>
    notifications
        .where((notification) => notification['delivered'] == true)
        .where((notification) => notification['suppressedByPrefs'] != true)
        .where((notification) => notification['isRead'] != true)
        .toList();
