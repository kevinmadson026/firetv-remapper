# Fire TV Remote Button Remapper

A lightweight utility script to remap dedicated app buttons on your Amazon Fire TV Stick remote control to open your preferred custom applications.

<img width="224" height="365" alt="Fire TV Remote" src="https://github.com/user-attachments/assets/377983f0-aa08-4f6e-b8de-720c8664aa5a" />

---

## ⚡ Features

* **Prime Video Button:** Remapped to open **SmartTube** (`org.smarttube.stable`) by default.
* **Netflix Button:** Remapped to open **LazerPlay** (`com.lazerplayer.app`) by default.
* **Disney Button:** Remapped to open **VLC** (`org.videolan.vlc`) by default.
* **Hulu Button:** Remapped to open **Downloader** (`com.esaba.downloader`) by default.
* **Keep-Alive Manager:** Host PC background monitor to ensure non-stop key interception.
* **Fully Customizable:** Easily change target applications or capture new button event codes.

---

## 💡 How It Works & Architecture

> **Important:** This script runs **on your computer** (Host PC), which communicates with your Fire TV via ADB.

Because Amazon Fire OS aggressively manages memory and frequently kills background user processes running locally on the TV, `run.bat` operates directly from your PC:
1. **Continuous Monitoring:** It maintains an active ADB bridge connection to capture remote control keypress events in real time.
2. **Preventive Restarts:** To prevent Fire OS or socket timeouts from killing the event listener, the host script performs continuous health checks and **automatically restarts the monitoring loop every 3 minutes**.
3. **PC Execution Requirement:** Your PC must remain turned on and connected to the same local network for the button remapping service to remain active.

---

## 📋 Prerequisites

Before running the script, ensure:
1. Your PC and Fire TV Stick are connected to the **same local Wi-Fi network**.
2. **ADB Debugging** is enabled on your Fire TV Stick.

### Manual Event Code Capture (Optional)
If your remote control model differs from the standard layout, you can capture button codes manually:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "getevent"
```

Press the dedicated app buttons on your remote control and observe the terminal output. Update the target event codes in `firetv-remapper.sh`:

```bash
TARGET_EVENT_PRIMEVIDEO="02e9"
TARGET_EVENT_NETFLIX="02e8"
TARGET_EVENT_DISNEY="02ea"
TARGET_EVENT_HULU="02eb"
```

---

## ⚙️ Step 1: Enable ADB Debugging on Fire TV

1. **Enable Developer Options:**
   * Go to **Settings** ⚙️ > **My Fire TV** > **About**.
   * Highlight your device name and press the **Select button 7 times rapidly** until you see *"No need, you are already a developer."*
2. **Turn on ADB Debugging:**
   * Return to **My Fire TV** > **Developer Options**.
   * Set **ADB Debugging** to **ON**.
3. **Find Your Fire TV IP Address:**
   * Go to **Settings** ⚙️ > **My Fire TV** > **About** > **Network**.
   * Note down the displayed **IP Address** (e.g., `192.168.1.7`).

---

## 🔍 How to Find App Package Names

To remap buttons to a different application, you need its exact Android package name (e.g., `org.smarttube.stable`).

### Method 1: Via ADB (Fastest)
```bash
# Connect to your Fire TV
adb connect YOUR_FIRE_TV_IP:5555

# List installed packages matching a keyword
adb shell pm list packages | grep -i "youtube"
```

### Method 2: Web Browser URL
Find the application page on the Google Play Store or APKMirror and locate the `id=` parameter in the URL:
* `https://play.google.com/store/apps/details?id=com.spotify.tv.android` $
ightarrow$ **`com.spotify.tv.android`**

### Method 3: Using Fire TV Apps
You can install apps like **Background Apps and Processes** or **App Inspector** directly on your Fire TV to inspect package names.

---

## 🛠️ Configuration & Setup

### 1. Set Your Fire TV IP Address
Open `run.bat` on your PC using a text editor (e.g., Notepad) and update the `IP_ADDRESS` variable:

```bat
set IP_ADDRESS=192.168.1.7:5555
```

### 2. Customize Target Applications (Optional)
Open `firetv-remapper.sh` and update the target package names:

```bash
APP01_PACKAGE="org.smarttube.stable" # Target app for Prime Video button
APP02_PACKAGE="com.lazerplayer.app"  # Target app for Netflix button
APP03_PACKAGE="org.videolan.vlc"     # Target app for Disney+ button
APP04_PACKAGE="com.esaba.downloader" # Target app for Hulu button
```

### 3. Push Script File to Fire TV
Transfer `firetv-remapper.sh` to the Fire TV's internal storage (`/sdcard/`):

```bash
adb connect YOUR_FIRE_TV_IP:5555
adb -s YOUR_FIRE_TV_IP:5555 push firetv-remapper.sh /sdcard/
```

---

## 🚀 How to Run

1. Ensure your Fire TV is turned on and connected to your Wi-Fi network.
2. Launch `run.bat` on your PC by double-clicking it.
3. If a dialog appears on your Fire TV asking **"Allow USB debugging?"**, check **"Always allow from this computer"** and select **OK**.
4. **Keep the command prompt window running on your PC.** The host script will maintain the active connection and automatically restart the monitoring loop every 3 minutes to prevent process termination.
