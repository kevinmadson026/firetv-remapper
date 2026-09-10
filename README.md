# Fire TV Remote Button Remapper

A lightweight utility for remapping dedicated application buttons—or any other button—on an Amazon Fire TV Stick remote to launch applications of your choice.

<img width="224" height="365" alt="Fire TV Remote" src="https://github.com/user-attachments/assets/377983f0-aa08-4f6e-b8de-720c8664aa5a" />

## Features

- **Fully customizable:** Change the application launched by each button or capture new button event codes to remap other buttons.

- **Default mappings:**
  - Prime Video opens YouTube (`com.google.android.youtube.tv` ).
  - Netflix opens Kodi (`org.xbmc.kodi`).
  - Disney opens VLC (`org.videolan.vlc`).
  - Hulu opens Downloader (`com.esaba.downloader`).

- **Keep-alive manager:** A background monitor running on the host computer keeps key interception active.

## How It Works

> This script runs on your computer, which communicates with the Fire TV through ADB.

Amazon Fire OS may terminate background processes running locally on the TV. For this reason, `run.bat` runs on the host computer and performs the following tasks:

1. Maintains an active ADB connection to capture remote-control keypresses in real time.

1. Performs health checks and automatically restarts the monitoring loop every three minutes to prevent timeouts from interrupting the listener.

1. Intercepts the original application launch, closes the default application, and opens the application configured for that button.

Your computer must remain powered on and connected to the same local network as the Fire TV for the remapping service to remain active.

## Prerequisites

Before running the script, make sure that:

1. Your computer and Fire TV Stick are connected to the same local Wi-Fi network.

1. ADB debugging is enabled on the Fire TV Stick.

1. ADB is installed and available in your computer's terminal or Command Prompt.

1. The repository's `.gitattributes` file is configured to preserve Unix-style LF line endings for shell scripts.

## Optional: Capture Button Event Codes

If your remote-control model uses a different button layout, you can capture the button codes manually:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "getevent"
```

Press the dedicated application buttons on the remote and observe the terminal output. Then update the target event codes in `firetv-remapper.sh`:

```bash
TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"
```

## Step 1: Enable ADB Debugging on Fire TV

### Enable Developer Options

1. Go to **Settings > My Fire TV > About**.

1. Highlight your device name and press the Select button seven times rapidly, until Fire TV confirms that developer options are enabled.

### Turn on ADB Debugging

1. Return to **My Fire TV > Developer Options**.

1. Set **ADB Debugging** to **On**.

### Find the Fire TV IP Address

1. Go to **Settings > My Fire TV > About > Network**.

1. Note the displayed IP address, such as `192.168.1.7`.

## Find Application Package Names

To remap a button to another application, you need its exact Android package name, such as `org.smarttube.stable`.

### Method 1: Using ADB

This is the fastest method:

```bash
# Connect to your Fire TV
adb connect YOUR_FIRE_TV_IP:5555

# List installed packages matching a keyword
adb shell pm list packages | grep -i "youtube"
```

### Method 2: Using a Web Browser

Find the application's page on the Google Play Store or APKMirror and look for the `id` parameter in the URL.

For example:

```
https://play.google.com/store/apps/details?id=com.spotify.tv.android
```

The package name in this example is `com.spotify.tv.android`.

### Method 3: Using a Fire TV Application

You can install applications such as **Background Apps and Processes** or **App Inspector** directly on your Fire TV to inspect package names.

## Configuration and Setup

### 1. Set the Fire TV IP Address

Open `run.bat` on Windows or `run_linux.sh` on Linux in a text editor, and update the `IP_ADDRESS` variable:

```
set IP_ADDRESS=192.168.1.7:5555
```

### 2. Customize Applications

To change the applications launched by the buttons, open `firetv-remapper.sh` and update the target package names:

```bash
APP01_PACKAGE="com.google.android.youtube.tv" # Prime Video button
APP02_PACKAGE="org.xbmc.kodi"                  # Netflix button
APP03_PACKAGE="org.videolan.vlc"               # Disney+ button
APP04_PACKAGE="com.esaba.downloader"           # Hulu button
```

### 3. Push and Prepare the Script on Fire TV

The following commands transfer the script to the Fire TV, remove any remaining CRLF characters, grant execution permission, and create the log file before the monitor starts:

```bash
# Connect to your Fire TV
adb connect YOUR_FIRE_TV_IP:5555

# Push the script to internal storage
adb -s YOUR_FIRE_TV_IP:5555 push firetv-remapper.sh /sdcard/

# Convert line endings to LF, grant execution permission, and create the log file
adb -s YOUR_FIRE_TV_IP:5555 shell "sed -i 's/\r//g' /sdcard/firetv-remapper.sh && chmod +x /sdcard/firetv-remapper.sh && touch /sdcard/firetv-remapper.log"
```

The `chmod +x` command is required so the script can be executed on the Fire TV. The `touch` command creates `/sdcard/firetv-remapper.log` before `log_watchdog.bat` tries to follow it, preventing repeated `WARNING: Log stream interrupted` messages during the first run.

If you prefer to run the preparation commands separately, use:

```bash
adb -s YOUR_FIRE_TV_IP:5555 push firetv-remapper.sh /sdcard/
adb -s YOUR_FIRE_TV_IP:5555 shell "chmod +x /sdcard/firetv-remapper.sh"
adb -s YOUR_FIRE_TV_IP:5555 shell "touch /sdcard/firetv-remapper.log"
```

## Running the Remapper

1. Make sure the Fire TV is turned on and connected to your Wi-Fi network.

1. Launch `run.bat` on Windows or `run_linux.sh` on Linux.

1. If the Fire TV displays an **Allow USB debugging?** dialog, select **Always allow from this computer** and then choose **OK**.

1. Keep the Command Prompt or terminal window open. The host script maintains the connection and automatically restarts the monitoring loop every three minutes to prevent the listener from being terminated.

## Troubleshooting

### The script fails with a syntax or interpreter error

This usually indicates that `firetv-remapper.sh` contains Windows CRLF line endings. Make sure the repository's `.gitattributes` configuration preserves LF line endings for shell scripts.

You can also normalize the file on the Fire TV by running:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "sed -i 's/\r//g' /sdcard/firetv-remapper.sh"
```

### Permission denied when starting the script

Grant execution permission again:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "chmod +x /sdcard/firetv-remapper.sh"
```

### `WARNING: Log stream interrupted` appears repeatedly

Create the log file before launching the monitor:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "touch /sdcard/firetv-remapper.log"
```

Also verify that the script is writing to the same path used by `log_watchdog.bat`.
