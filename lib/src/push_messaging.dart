import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meta/meta.dart';
import 'package:push_messaging/push_messaging.dart';

/// The default icon shown in notification on Android devices.
const kDefaultAndroidNotificationIcon = 'ic_default_push_notification';

const _kDefaultSoundValue = 'default';

/// Signature for a callback that get triggered when the user taps on a
/// notification.
typedef OnNotificationOpened = void Function(Map<String, dynamic>? data);

/// {@template push_notification_service}
/// An interface for managing push notifications.
/// {@endtemplate}
abstract class Notifications {
  /// {@template push_messaging_service.setup_notifications}
  /// Sets up push messaging notifications.
  ///
  /// This must be called before any other method of this service is used.
  /// Normally when the application launches.
  ///
  /// On Android [enableForegroundNotifications] is only needed if the
  /// [androidSettings] don't contain a default channel and [PushMessaging]
  /// needs to create the default channel.
  /// {@endtemplate}
  Future<void> setupNotifications({
    AndroidNotificationSettings androidSettings =
        const AndroidNotificationSettings(),
    OnNotificationOpened? onNotificationSelected,
    bool enableForegroundNotifications = false,
    bool shouldUpdateAndroidNotificationChannels = true,
  });

  /// {@macro push_messaging_service.update_android_notification_channels}
  /// Update the Android notification channels provided by the
  /// [notificationChannelSettings].
  ///
  /// Channels that are not contained in the [notificationChannelSettings] will
  /// get removed, if they exists.
  /// {@endtemplate}
  Future<void> updateAndroidNotificationChannels({
    required AndroidNotificationChannelSettings notificationChannelSettings,
  });

  /// {@template push_messaging_service.show_remote_message_notification}
  /// Shows the given [message] as a local notification.
  ///
  /// If the [message] does not include a title for the notification, the
  /// the notification won't get shown.
  /// {@endtemplate}
  Future<void> showRemoteMessageNotification({
    required RemoteMessage message,
  });
}

/// {@template push_messaging}
/// A class responsible for interacting with the push messaging of the
/// application.
/// {@endtemplate}
class PushMessaging extends _PushMessaging {}

/// {@macro push_messaging}
class _PushMessaging implements Notifications {
  /// {@macro push_messaging}
  _PushMessaging({
    FirebaseMessaging? firebaseMessaging,
    FlutterLocalNotificationsPlugin? localNotificationsPlugin,
  })  : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
        _localNotificationsPlugin =
            localNotificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _firebaseMessaging;

  /// The plugin that communicates with the native notification components.
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin;

  /// The [AndroidNotificationSettings] specified when [setupNotifications] gets
  /// called.
  late AndroidNotificationSettings _androidNotificationSettings;

  @internal
  @override
  Future<void> setupNotifications({
    AndroidNotificationSettings androidSettings =
        const AndroidNotificationSettings(),
    OnNotificationOpened? onNotificationSelected,
    bool enableForegroundNotifications = false,
    bool shouldUpdateAndroidNotificationChannels = true,
  }) async {
    _androidNotificationSettings = androidSettings;

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: enableForegroundNotifications,
      badge: enableForegroundNotifications,
      sound: enableForegroundNotifications,
    );

    await _localNotificationsPlugin.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings(
          androidSettings.defaultNotificationIcon,
        ),
        iOS: const DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: onNotificationSelected != null
          ? (response) => onNotificationSelected(
                response.payload != null
                    ? jsonDecode(response.payload!) as Map<String, dynamic>?
                    : null,
              )
          : null,
    );

    if (shouldUpdateAndroidNotificationChannels) {
      await updateAndroidNotificationChannels(
        notificationChannelSettings:
            androidSettings.notificationChannelSettings,
      );
    }
  }

  @override
  @internal
  Future<void> updateAndroidNotificationChannels({
    required AndroidNotificationChannelSettings notificationChannelSettings,
  }) async {
    final androidNotifications =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidNotifications != null) {
      // we are running on android
      await androidNotifications.createNotificationChannel(
        notificationChannelSettings.defaultChannel,
      );

      final availableChannels =
          await androidNotifications.getNotificationChannels();

      for (final channel in notificationChannelSettings.channels) {
        await androidNotifications.createNotificationChannel(channel);
      }

      final channelsToDelete = availableChannels
              ?.where(
                (channel) =>
                    channel.id !=
                        notificationChannelSettings.defaultChannel.id &&
                    !notificationChannelSettings.channels
                        .map((e) => e.id)
                        .contains(channel.id),
              )
              .toList() ??
          const [];

      for (final channelToDelete in channelsToDelete) {
        if (channelToDelete.name ==
            notificationChannelSettings.defaultChannel.id) {
          continue;
        }

        await androidNotifications
            .deleteNotificationChannel(channelToDelete.id);
      }
    }
  }

  /// {@template push_messaging.request_permissions}
  /// Requests permissions for displaying notifications to the user.
  ///
  /// Return `true`if the user granted request for showing notifications,
  /// otherwise `false`.
  ///
  /// See also:
  /// - `requestPermissions` on [FirebaseMessaging] for further informations
  /// about which parameter does what.
  /// {@endtemplate}
  Future<bool> requestPermissions({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
  }) async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: alert,
      announcement: announcement,
      badge: badge,
      carPlay: carPlay,
      criticalAlert: criticalAlert,
      provisional: provisional,
      sound: sound,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// {@template push_messaging.get_token}
  /// Get the unique push messaging token of the current device.
  /// {@endtemplate}
  Future<String?> getToken({
    bool recreateToken = false,
  }) async {
    if (recreateToken) {
      await removeToken();
    }
    return _firebaseMessaging.getToken();
  }

  Future<void> removeToken() async {
    return _firebaseMessaging.deleteToken();
  }

  /// {@template push_messaging.get_initial_message}
  /// Gets the notification that launched the application by clicking on it and
  /// returns its data.
  ///
  /// This will only return a value if the application has be terminated before
  /// it got launched.
  /// {@endtemplate}
  Future<Map<String, dynamic>?> getAppLaunchNotificationData() async {
    final fcmMessage = await _firebaseMessaging.getInitialMessage();
    if (fcmMessage != null) {
      return fcmMessage.data;
    } else {
      return _getLaunchNotification();
    }
  }

  @override
  @internal
  Future<void> showRemoteMessageNotification({
    required RemoteMessage message,
  }) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;

    if (title != null) {
      final androidNotificationDetails = notification?.android != null
          ? await _getAndroidNotificationDetails(notification!.android!)
          : null;

      final darwinNotificationDetails = notification?.apple != null
          ? await _getDarwinNotificationDetails(notification!.apple!)
          : null;

      await _showNotification(
        id: message.messageId.hashCode,
        title: title,
        body: notification?.body ?? message.data['body'] as String?,
        android: androidNotificationDetails,
        ios: darwinNotificationDetails,
        data: message.data,
      );
    }
  }

  /// {@template push_messaging.show_notification}
  /// Shows a custom notification with the given [title] and [body].
  /// {@endtemplate}
  Future<void> _showNotification({
    required int id,
    required String title,
    String? body,
    AndroidNotificationDetails? android,
    DarwinNotificationDetails? ios,
    Map<String, dynamic>? data,
  }) async {
    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: android,
        iOS: ios,
      ),
      payload: jsonEncode(data),
    );
  }

  Future<Map<String, dynamic>?> _getLaunchNotification() async {
    final localLaunchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();

    if (localLaunchDetails?.notificationResponse?.payload != null &&
        localLaunchDetails!.didNotificationLaunchApp) {
      return jsonDecode(
        localLaunchDetails.notificationResponse!.payload!,
      ) as Map<String, dynamic>?;
    }

    return null;
  }

  Future<AndroidNotificationDetails> _getAndroidNotificationDetails(
    AndroidNotification androidNotification,
  ) async {
    AndroidNotificationChannel? androidChannel;

    if (androidNotification.channelId != null) {
      final androidNotifications =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final availableChannels =
          await androidNotifications?.getNotificationChannels();

      androidChannel = availableChannels?.firstWhere(
        (element) => element.id == androidNotification.channelId,
      );
    }

    final androidSound = androidNotification.sound;

    return AndroidNotificationDetails(
      androidChannel?.id ??
          _androidNotificationSettings
              .notificationChannelSettings.defaultChannel.id,
      androidChannel?.name ??
          _androidNotificationSettings
              .notificationChannelSettings.defaultChannel.name,
      playSound: androidSound != null,
      sound: androidSound != null && androidSound != _kDefaultSoundValue
          ? RawResourceAndroidNotificationSound(androidSound)
          : null,
      importance: _fcmPriorityToLocalNotificationImportance(
        androidNotification.priority,
      ),
      priority: _fcmPriorityToLocalNotificationPriority(
        androidNotification.priority,
      ),
      visibility: _fcmVisibilityToLocalNotificationVisibility(
        androidNotification.visibility,
      ),
      icon: androidNotification.smallIcon,
      tag: androidNotification.tag,
      ticker: androidNotification.ticker,
    );
  }

  Future<DarwinNotificationDetails> _getDarwinNotificationDetails(
    AppleNotification appleNotification,
  ) async {
    final appleSound = appleNotification.sound;

    return DarwinNotificationDetails(
      presentSound: appleSound != null,
      sound: appleSound?.name != null && appleSound?.name != _kDefaultSoundValue
          ? appleSound?.name
          : null,
      presentBadge: appleNotification.badge != null,
      badgeNumber: appleNotification.badge != null
          ? int.parse(appleNotification.badge!)
          : null,
    );
  }

  Priority _fcmPriorityToLocalNotificationPriority(
    AndroidNotificationPriority? fcmPriority,
  ) {
    if (fcmPriority == null) {
      return Priority.defaultPriority;
    }

    switch (fcmPriority) {
      case AndroidNotificationPriority.minimumPriority:
        return Priority.min;
      case AndroidNotificationPriority.lowPriority:
        return Priority.low;
      case AndroidNotificationPriority.defaultPriority:
        return Priority.defaultPriority;
      case AndroidNotificationPriority.highPriority:
        return Priority.high;
      case AndroidNotificationPriority.maximumPriority:
        return Priority.max;
    }
  }

  Importance _fcmPriorityToLocalNotificationImportance(
    AndroidNotificationPriority? fcmImportance,
  ) {
    if (fcmImportance == null) {
      return Importance.defaultImportance;
    }

    switch (fcmImportance) {
      case AndroidNotificationPriority.minimumPriority:
        return Importance.min;
      case AndroidNotificationPriority.lowPriority:
        return Importance.low;
      case AndroidNotificationPriority.defaultPriority:
        return Importance.defaultImportance;
      case AndroidNotificationPriority.highPriority:
        return Importance.high;
      case AndroidNotificationPriority.maximumPriority:
        return Importance.max;
    }
  }

  NotificationVisibility? _fcmVisibilityToLocalNotificationVisibility(
    AndroidNotificationVisibility? fcmVisibility,
  ) {
    if (fcmVisibility == null) {
      return null;
    }

    switch (fcmVisibility) {
      case AndroidNotificationVisibility.private:
        return NotificationVisibility.private;
      case AndroidNotificationVisibility.public:
        return NotificationVisibility.public;
      case AndroidNotificationVisibility.secret:
        return NotificationVisibility.secret;
    }
  }
}
