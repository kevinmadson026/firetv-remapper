# Fire TV Remote Button Remapper

A lightweight utility script to remap dedicated app buttons ( or any button ) on your Amazon Fire TV Stick remote control to open your preferred custom applications.

<img width="224" height="365" alt="Fire TV Remote" src="https://github.com/user-attachments/assets/377983f0-aa08-4f6e-b8de-720c8664aa5a" />

---

## ⚡ Features

* **Fully Customizable:** Easily change which app you want to open or capture new button event codes to remap any button.
  * **Prime Video Button:** Remapped to open **YouTube** (`com.google.android.youtube.tv`) by default.
  * **Netflix Button:** Remapped to open **Kodi** (`org.xbmc.kodi`) by default.
  * **Disney Button:** Remapped to open **VLC** (`org.videolan.vlc`) by default.
  * **Hulu Button:** Remapped to open **Downloader** (`com.esaba.downloader`) by default.
* **Keep-Alive Manager:** Host PC background monitor to ensure non-stop key interception.

---

## 💡 How It Works & Architecture

> **Important:** This script runs **on your computer** (Host PC), which communicates with your Fire TV via ADB.

Because Amazon Fire OS aggressively manages memory and frequently kills background user processes running locally on the TV, `run.bat` operates directly from your PC:
1. **Continuous Monitoring:** It maintains an active ADB bridge connection to capture remote control keypress events in real time.
2. **Preventive Restarts:** To prevent Fire OS or socket timeouts from killing the event listener, the host script performs continuous health checks and **automatically restarts the monitoring loop every 3 minutes**.
3. **PC Execution Requirement:** Your PC must remain turned on and connected to the same local network for the button remapping service to remain active.
4. **Auto App Interception:** Immediately closes the default application launched by the button press (e.g., Netflix) and redirects to your custom app instead.

---

## 📋 Prerequisites

Before running the script, ensure:
1. Your PC and Fire TV Stick are connected to the **same local Wi-Fi network**.
2. **ADB Debugging** is enabled on your Fire TV Stick.
3. **Git Line Endings (Windows Users):** If you clone this repository on Windows, ensure bash scripts retain LF (Unix) line endings by setting up `.gitattributes`.

### Manual Event Code Capture (Optional)
If your remote control model differs from the standard layout, you can capture button codes manually:

```bash
adb -s YOUR_FIRE_TV_IP:5555 shell "getevent"
