import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    tz.initializeTimeZones();

    // 1. Request Permissions (especially for Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );

    // 2. Setup FCM Foreground Messaging
    // When the app is in the foreground, FCM doesn't show the tray notification automatically.
    // We handle it here and use local notifications to show it in the tray.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          title: message.notification!.title ?? "Update",
          body: message.notification!.body ?? "",
        );
      }
    });

    // 3. Get the token (optional, but good for debugging)
    String? token = await _fcm.getToken();
    print("FCM Token: $token");
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'main_channel',
          'General Notifications',
          channelDescription: 'Appointment and result updates',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  // Schedule a notification for 30 days later
  Future<void> schedule30DayReminder({
    required int id,
    required String labName,
    DateTime? appointmentDate,
  }) async {
    final baseDate = appointmentDate ?? DateTime.now();
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      baseDate.add(const Duration(days: 30)),
      tz.local,
    );

    // Ensure we don't schedule in the past
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      'Time for a Checkup!',
      'It has been a month since your last test at $labName. Book a new appointment to track your health.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          channelDescription: '30-day health re-test reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  // Schedule a reminder 1 hour before the appointment
  Future<void> scheduleAppointmentReminder({
    required int id,
    required String labName,
    required String testType,
    required DateTime appointmentDateTime,
  }) async {
    final scheduledDate = tz.TZDateTime.from(
      appointmentDateTime.subtract(const Duration(hours: 1)),
      tz.local,
    );

    // If the reminder time is already past, skip it
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      'Appointment Reminder',
      'Your $testType appointment at $labName is in 1 hour.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_reminder_channel',
          'Appointment Reminders',
          channelDescription: 'Reminders before your scheduled test',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
