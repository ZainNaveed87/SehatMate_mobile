# SehatMate Android notification setup

These changes are required once in the local Flutter project.

## 1. Keep only one MainActivity

Delete the old file if it still exists:

`android/app/src/main/kotlin/com/example/SehatMate_ai/MainActivity.kt`

Keep this file only:

`android/app/src/main/kotlin/com/secretstechies/sehatmate/MainActivity.kt`

Its complete content should be:

```kotlin
package com.secretstechies.sehatmate

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

Do not create notification channels manually in `MainActivity`. The Flutter
notification plugin creates and manages the channel.

## 2. AndroidManifest.xml

In `android/app/src/main/AndroidManifest.xml`, add these directly inside the
opening `<manifest>` element and before `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

Add these inside `<application>`:

```xml
<receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
    android:exported="false" />

<receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

Confirm that the existing activity still has:

```xml
android:name=".MainActivity"
```

## 3. android/app/build.gradle.kts

Inside `android { defaultConfig { ... } }` add:

```kotlin
multiDexEnabled = true
```

Inside `android { ... }` use:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
}
```

Inside `dependencies { ... }` add:

```kotlin
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
```

Keep `compileSdk = 37` in this project.

## 4. Install and run

Run from the Flutter project folder:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=https://sehatmate-api.secretstechies.com/api --dart-define=GOOGLE_WEB_CLIENT_ID=333869910734-2ju6rlcq5ha1mohotb782a8l8r8pq712.apps.googleusercontent.com
```

When **Activate Care Plan** is pressed, Android may ask for notification and
exact-alarm permissions. Both must be allowed for exact reminders.

## Safety behavior

- A plan can activate only after every instruction is reviewed, every care gap
  is resolved, every reality-check question is answered, and every scheduled
  task has an exact confirmed time.
- The app schedules only the next confirmed occurrence. It does not invent a
  time or repeat a medicine indefinitely beyond the written plan.
- Draft plans can be deleted from the Draft tab. Active and completed plans are
  protected from deletion.
