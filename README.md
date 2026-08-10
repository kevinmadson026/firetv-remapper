# Fire TV Remote Button Remapper

A lightweight utility script to remap dedicated app buttons on your Amazon Fire TV Stick remote control to open your preferred custom applications.

---

## ⚡ Features

* **Prime Video Button:** Remapped to open **SmartTube** (`org.smarttube.stable`) by default.
* **Netflix Button:** Remapped to open **LazerPlay** (`com.lazerplayer.app`) by default.
* **Fully Customizable:** Easily change the target applications by editing package names.

---

## 📋 Prerequisites

Before running the script, ensure:
1. Your PC and Fire TV Stick are connected to the **same local Wi-Fi network**.
2. **ADB Debugging** is enabled on your Fire TV Stick.

---

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
