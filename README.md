Things to do:

1. change firebase messaging notification icon if necessary with the name `ic_default_push_notification`

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_default_push_notification" />
```

2. change firebase default channel if foreground messages are wanted

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="general" />
```
3. wrap `MaterialApp` with `PushMessagingHandler`
4. call `PushMessaging.requestPermissions` on app launch
5. [setup firebase Messaging](https://firebase.google.com/docs/cloud-messaging/flutter/client)
