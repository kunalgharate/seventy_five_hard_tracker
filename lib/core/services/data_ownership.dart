import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which account owns the device-local (Hive) data so one account's
/// challenges, progress, journal, and tasks are never shown, uploaded, or
/// published while another account is signed in on the same device.
///
/// A `null` owner means "no owner recorded yet" — legacy installs adopt the
/// currently signed-in account at app start (see main.dart splash flow).
class DataOwnership {
  static const String _ownerKey = 'localDataOwnerUid';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ownerKey);
  }

  static Future<void> claim(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, uid);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownerKey);
  }

  /// True when no owner is recorded yet or the recorded owner is [uid].
  static Future<bool> isOwnedBy(String? uid) async {
    final owner = await read();
    return owner == null || owner == uid;
  }

  /// True when local data is recorded as belonging to a different account.
  static Future<bool> ownedByOther(String? uid) async {
    final owner = await read();
    return owner != null && uid != null && owner != uid;
  }
}
