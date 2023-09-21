import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings("sync");
    await isAndroidPermissionGranted();

    var initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification:
            (int id, String? title, String? body, String? payload) async {});

    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    await notificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {});
  }

  Future<void> isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      if (!granted) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation?.requestPermission();
      }
    }
  }

  void showDownloadNotification(int numberOfActiveDownloads) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notification channel for active downloads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID (you can use a different value for each notification)
      'Active Downloads', // Notification title
      '$numberOfActiveDownloads download(s) in progress', // Notification message
      platformChannelSpecifics,
    );
  }

  void showUploadNotification(int numberOfActiveUploads) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'upload_channel',
      'Uploads',
      channelDescription: 'Notification channel for active uploads',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID (you can use a different value for each notification)
      'Active Uploads', // Notification title
      '$numberOfActiveUploads upload(s) in progress', // Notification message
      platformChannelSpecifics,
    );
  }
}
