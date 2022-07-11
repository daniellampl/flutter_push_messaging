import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _kDefaultChannelId = 'default';

const _kDefaultChannelName = 'General Notifications';

const _kDefaultNotificationIcon = 'ic_default_push_notification';

class AndroidNotificationSettings {
  const AndroidNotificationSettings({
    this.defaultNotificationIcon = _kDefaultNotificationIcon,
    this.notificationChannelSettings =
        const AndroidNotificationChannelSettings(),
  });

  /// The default notification icon name.
  ///
  /// Must match with the icon provided in the AndroidManifest.xml as
  /// `com.google.firebase.messaging.default_notification_icon` meta-data value.
  ///
  /// Defaults to "ic_default_push_notification".
  final String defaultNotificationIcon;

  /// The notification channel settings.
  final AndroidNotificationChannelSettings notificationChannelSettings;
}

class AndroidNotificationChannelSettings {
  const AndroidNotificationChannelSettings({
    this.defaultChannel = const AndroidNotificationChannel(
      _kDefaultChannelId,
      _kDefaultChannelName,
      importance: Importance.max,
    ),
    this.channels = const [],
  });

  /// The default notification channel.
  ///
  /// Its id must match with the default channel provided in the
  /// AndroidManifest.xml as
  /// `com.google.firebase.messaging.default_notification_channel_id` meta-data
  /// value.
  ///
  /// Defaults to a [AndroidNotificationChannel] with default values.
  final AndroidNotificationChannel defaultChannel;

  /// A list of notification channels.
  ///
  /// Defaults to an empty list.
  final List<AndroidNotificationChannel> channels;
}
