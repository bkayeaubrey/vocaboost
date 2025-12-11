import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:io' show Platform;

/// Service for managing push notifications
/// Handles spaced repetition reminders and daily challenge notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification IDs
  static const int dailyReminderNotificationId = 1;
  static const int spacedRepetitionNotificationId = 2;
  static const int streakReminderNotificationId = 3;
  static const int dailyChallengeNotificationId = 4;
  static const int achievementNotificationId = 5;

  // Notification channel IDs (Android)
  static const String dailyChannelId = 'daily_reminders';
  static const String learningChannelId = 'learning_reminders';
  static const String achievementChannelId = 'achievements';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip initialization on web
      if (kIsWeb) {
        debugPrint('Notifications not supported on web');
        _isInitialized = true;
        return;
      }

      // Initialize timezone
      tz_data.initializeTimeZones();

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels (Android 8.0+)
      await _createNotificationChannels();

      _isInitialized = true;
      debugPrint('✅ Notification service initialized');

      // Schedule default reminders if enabled
      await _scheduleDefaultReminders();
    } catch (e) {
      debugPrint('❌ Failed to initialize notifications: $e');
      _isInitialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;
    
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Daily reminders channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            dailyChannelId,
            'Daily Reminders',
            description: 'Reminders to practice Bisaya daily',
            importance: Importance.high,
          ),
        );

        // Learning reminders channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            learningChannelId,
            'Learning Reminders',
            description: 'Spaced repetition review reminders',
            importance: Importance.defaultImportance,
          ),
        );

        // Achievements channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            achievementChannelId,
            'Achievements',
            description: 'Badge and milestone notifications',
            importance: Importance.low,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to create notification channels: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Navigation is handled by the app based on payload
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
    return false;
  }

  /// Schedule default reminders based on user preferences
  Future<void> _scheduleDefaultReminders() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if reminders are enabled (default: true)
    final remindersEnabled = prefs.getBool('reminders_enabled') ?? true;
    if (!remindersEnabled) return;

    // Get reminder time (default: 9:00 AM)
    final reminderHour = prefs.getInt('reminder_hour') ?? 9;
    final reminderMinute = prefs.getInt('reminder_minute') ?? 0;

    // Schedule daily learning reminder
    await scheduleDailyReminder(
      hour: reminderHour,
      minute: reminderMinute,
    );
  }

  /// Schedule a daily learning reminder
  Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      // Cancel existing daily reminder
      await _notifications.cancel(dailyReminderNotificationId);

      // Calculate next occurrence
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        dailyReminderNotificationId,
        '📚 Time to Learn Bisaya!',
        'Keep your streak alive! Your daily challenges are waiting.',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            dailyChannelId,
            'Daily Reminders',
            channelDescription: 'Reminders to practice Bisaya daily',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_reminder',
      );

      // Save reminder settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_hour', hour);
      await prefs.setInt('reminder_minute', minute);

      debugPrint('✅ Daily reminder scheduled for $hour:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Failed to schedule daily reminder: $e');
    }
  }

  /// Schedule a spaced repetition reminder
  Future<void> scheduleSpacedRepetitionReminder({
    required int wordsToReview,
    int delayMinutes = 30,
  }) async {
    if (kIsWeb || !_isInitialized || wordsToReview == 0) return;

    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(
        Duration(minutes: delayMinutes),
      );

      await _notifications.zonedSchedule(
        spacedRepetitionNotificationId,
        '🔄 Words Ready for Review',
        '$wordsToReview ${wordsToReview == 1 ? 'word' : 'words'} due for spaced repetition review!',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            learningChannelId,
            'Learning Reminders',
            channelDescription: 'Spaced repetition review reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'spaced_repetition',
      );

      debugPrint('✅ Spaced repetition reminder scheduled for $delayMinutes minutes');
    } catch (e) {
      debugPrint('Failed to schedule spaced repetition reminder: $e');
    }
  }

  /// Schedule a streak reminder (sent in evening if user hasn't practiced)
  Future<void> scheduleStreakReminder() async {
    if (kIsWeb || !_isInitialized) return;

    try {
      // Cancel existing streak reminder
      await _notifications.cancel(streakReminderNotificationId);

      // Schedule for 7 PM if user hasn't practiced today
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        19, // 7 PM
        0,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        streakReminderNotificationId,
        '🔥 Don\'t Break Your Streak!',
        'Complete a quick lesson to keep your learning streak going!',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            dailyChannelId,
            'Daily Reminders',
            channelDescription: 'Reminders to practice Bisaya daily',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'streak_reminder',
      );

      debugPrint('✅ Streak reminder scheduled');
    } catch (e) {
      debugPrint('Failed to schedule streak reminder: $e');
    }
  }

  /// Show an immediate notification for daily challenge
  Future<void> showDailyChallengeNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await _notifications.show(
        dailyChallengeNotificationId,
        '🎯 $title',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            dailyChannelId,
            'Daily Reminders',
            channelDescription: 'Reminders to practice Bisaya daily',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'daily_challenge',
      );
    } catch (e) {
      debugPrint('Failed to show daily challenge notification: $e');
    }
  }

  /// Show an achievement unlock notification
  Future<void> showAchievementNotification({
    required String badgeName,
    required String description,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await _notifications.show(
        achievementNotificationId,
        '🏆 Achievement Unlocked!',
        '$badgeName - $description',
        NotificationDetails(
          android: AndroidNotificationDetails(
            achievementChannelId,
            'Achievements',
            channelDescription: 'Badge and milestone notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'achievement',
      );
    } catch (e) {
      debugPrint('Failed to show achievement notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
    debugPrint('All notifications cancelled');
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _notifications.cancel(id);
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reminders_enabled') ?? true;
  }

  /// Enable or disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_enabled', enabled);

    if (enabled) {
      await _scheduleDefaultReminders();
    } else {
      await cancelAllNotifications();
    }
  }

  /// Get the scheduled reminder time
  Future<Map<String, int>> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt('reminder_hour') ?? 9,
      'minute': prefs.getInt('reminder_minute') ?? 0,
    };
  }

  /// Update reminder time
  Future<void> updateReminderTime(int hour, int minute) async {
    await scheduleDailyReminder(hour: hour, minute: minute);
  }

  /// Cancel streak reminder (call when user practices)
  Future<void> cancelStreakReminder() async {
    await cancelNotification(streakReminderNotificationId);
  }
}
