# Fire TV Remote Button Remapper

A lightweight utility script to remap dedicated app buttons on your Amazon Fire TV Stick remote control to open your preferred custom applications.

<img width="224" height="365" alt="images (4)" src="https://github.com/user-attachments/assets/377983f0-aa08-4f6e-b8de-720c8664aa5a" />


---

## ⚡ Features

* **Prime Video Button:** Remapped to open **SmartTube** (`org.smarttube.stable`) by default.
* **Netflix Button:** Remapped to open **LazerPlay** (`com.lazerplayer.app`) by default.
* **Disney Button:** Remapped to open **Vlc** (`org.videolan.vlc`) by default.
* **Hulu Button:** Remapped to open **Downloader** (`com.esaba.downloader`) by default.
* **Fully Customizable:** Easily change the target applications by editing package names.
* **Keep-Alive Manager:** Script to keep the Fire TV process running continuously.

---

## 📋 Prerequisites

Before running the script, ensure:
1. Your PC and Fire TV Stick are connected to the **same local Wi-Fi network**.
2. **ADB Debugging** is enabled on your Fire TV Stick.

**Note:** If your remote control model is different from the one used in this guide, you will need to capture the codes for each button manually before remapping.

---

## Capture the Button Codes

Run the following command in your terminal to monitor remote control events in real time:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "getevent"
```

Next, press the buttons on your remote control that you wish to remap and observe the event codes printed in the terminal output.
Once you have identified the code corresponding to each button in the logs, update the variable values in your script accordingly:

```bash
TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"
```

## ⚙️ Step 1: Enable ADB Debugging on Fire TV

Follow these steps to enable ADB Debugging and locate your IP address:

### 1. Enable Developer Options
1. On your Fire TV, go to **Settings** ⚙️ > **My Fire TV** > **About**.
2. Highlight your device name (e.g., *Fire TV Stick*) and press the **Select button on your remote 7 times rapidly**.
3. You will see a prompt saying: *"No need, you are already a developer."*

### 2. Turn on ADB Debugging
1. Press **Back** to return to **My Fire TV**.
2. Select **Developer Options**.
3. Turn **ADB Debugging** to **ON**.

### 3. Find Your Fire TV IP Address
1. Go to **Settings** ⚙️ > **My Fire TV** > **About** > **Network**.
2. Note down the **IP Address** displayed on the right (e.g., `192.168.1.7`).

---

## 🔍 How to Find App Package Names

To remap buttons to a different app, you need its exact package name (e.g., `com.netflix.ninja` or `org.smarttube.stable`). Here are two easy ways to find it:

### Method 1: Using ADB (Fastest)
If you have ADB installed on your computer, connect to your Fire TV and list installed packages:

```bash
# Connect to your Fire TV
adb connect YOUR_FIRE_TV_IP:5555

# List all installed packages
adb shell pm list packages

# Search for a specific app (e.g., YouTube or Spotify)
adb shell pm list packages | grep -i "youtube"
```

### Method 2: Via Web Browser / URL
Search for the app on the Google Play Store web version or an app repository (like APKMirror/APKPure):
1. Open the app page in a web browser.
2. Look at the URL for the `id=` parameter.
   * Example URL: `https://play.google.com/store/apps/details?id=com.spotify.tv.android`
   * The package name is **`com.spotify.tv.android`**.

### Method 3: Using Fire TV Apps
You can install an app like **Background Apps and Processes** or **App Inspector** directly on your Fire TV via the Amazon Appstore to view exact package names.

---

## 🛠️ Configuration & Setup

### 1. Set Your IP Address
Open `run.bat` in a text editor (e.g., Notepad) and update the `IP_ADDRESS` variable with your Fire TV's IP:

```bat
set IP_ADDRESS=192.168.1.7:5555
```

### 2. (Optional) Customize Target Apps
Open `firetv-remapper.sh` in a text editor and update the target package names:

```bash
APP01_PACKAGE="org.smarttube.stable" # Target app for Prime Video button
APP02_PACKAGE="com.lazerplayer.app"  # Target app for Netflix button
APP03_PACKAGE="org.videolan.vlc"     # Target app for Disney+ button
APP04_PACKAGE="com.esaba.downloader" # Target app for Hulu button
```

### 3. Transfer the Script File to Fire TV
Before executing the script, push `firetv-remapper.sh` to your Fire TV's internal storage (`/sdcard/`):

```bash
# Connect to Fire TV
adb connect YOUR_FIRE_TV_IP:5555

# Push the remapper script to the Fire TV internal storage
adb -s YOUR_FIRE_TV_IP:5555 push firetv-remapper.sh /sdcard/
```

---

## 🚀 How to Run

1. Make sure your Fire TV is turned on.
2. Execute `run.bat` by double-clicking it.
3. If a prompt appears on your Fire TV asking to **"Allow USB debugging?"**, check **"Always allow from this computer"** and select **OK**.
4. You're ready to go!

---

