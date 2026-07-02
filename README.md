# RKN Availability Checker (Android App)

A simple, terminal-styled Android application that checks the availability of services via DNS resolution and HTTPS connection status.

![Application Icon](app/src/main/res/mipmap-xxhdpi/ic_launcher.png)

## Features
- **Terminal Aesthetic**: Deep dark console theme, monospaced fonts, and color-coded statuses (cyan for headers, green for success, red for errors).
- **Asynchronous Checks**: Runs network queries on background IO threads (using Kotlin Coroutines) to keep the UI smooth.
- **Auto-Scrolling Log Output**: Displays real-time checking steps and automatically scrolls to the latest output.
- **Detailed Summary**: Prints a clean overview of DNS resolution rates and HTTPS success counts.
- **Easy Testing**: Press the **RESTART TEST** button at the bottom to rerun the checks.

---

## How to Build and Deploy

### Prerequisites
1. **Java SDK**: Version 17 (recommended version for the included Gradle configurations).
2. **Android SDK**: API 36 platforms (automatically downloaded by the wrapper if missing).
3. **ADB**: Command-line tool to deploy files to your device.

### 1. Build the APK
Use the Gradle wrapper to build the debug package:
```bash
# Set your Java 17 path if not globally active, e.g.:
export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-17.jdk/Contents/Home

# Compile the application
./gradlew assembleDebug
```
The compiled package will be created at: `app/build/outputs/apk/debug/app-debug.apk`.

### 2. Install on Device via ADB
Verify that your Android device (or emulator) is connected and developer mode/USB debugging is active, then run:
```bash
# Check connected devices
adb devices

# Install the app (replace with your device ID if multiple are connected)
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### 3. Launch the Application
Start the activity directly via ADB:
```bash
adb shell am start -n com.example.rknchecker/com.example.rknchecker.MainActivity
```

---

## How to Expand the List of Hosts

The domain list is declared in [MainActivity.kt](app/src/main/java/com/example/rknchecker/MainActivity.kt).

To add or remove target domains:
1. Open the file: [MainActivity.kt](app/src/main/java/com/example/rknchecker/MainActivity.kt#L72-L82).
2. Find the `ConsoleCheckerScreen` Composable function and locate the `domains` list definition:
   ```kotlin
   val domains = remember {
       listOf(
           "yandex.ru",
           "mail.ru",
           "github.com",
           "google.com",
           "facebook.com"
           // Add your custom domains here, for example:
           // "telegram.org",
           // "instagram.com"
       )
   }
   ```
3. Save the file and compile/reinstall the app. The interface will automatically adapt to list and test the new entries.
