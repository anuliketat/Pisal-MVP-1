import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'fin_alert_tx';
const _channelName = 'Transactions';

/// Local notifications when new items need review (after sync).
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
      ),
    );
    // Android 13+ (API 33): runtime notification permission.
    await androidImpl?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> showNewTransactions(int count) async {
    if (!_ready) await init();
    if (count <= 0) return;
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'New parsed transactions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New transactions',
      '$count new transaction(s) — tap Fin Alert to tag.',
      details,
    );
  }
}
