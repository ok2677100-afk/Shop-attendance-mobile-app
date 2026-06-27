# 🏪 Shop Attendance Flutter APK

A production-ready Employee Attendance System built in Flutter (Dart).

## ✅ Features
| Feature | Detail |
|---|---|
| 🫆 Biometric Auth | Real Android fingerprint / face unlock via `local_auth` |
| 📶 WiFi Geo-fence | Reads actual SSID, blocks punch if wrong network |
| 📍 Local IP | Displays device local IP on receipt |
| 🧾 Digital Receipt | Beautiful dark-themed receipt card |
| 📱 QR Code | Anti-tamper QR containing all verified metadata |
| 💾 Gallery Save | Saves receipt as PNG to phone gallery |
| 🇵🇰 Bilingual | English + Urdu labels throughout |
| ⚙ Admin Panel | Set allowed WiFi SSID, saved across sessions |

---

## 📁 Files You Need to Upload to GitHub

```
ShopAttendanceFlutter/
├── lib/
│   └── main.dart                    ← Entire Flutter app (1 file)
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml      ← All Android permissions
├── .github/
│   └── workflows/
│       └── build-apk.yml            ← Auto-build script
├── pubspec.yaml                     ← Dependencies
└── .gitignore
```

---

## 🚀 Baby-Step Guide: GitHub → APK

### STEP 1 — Create GitHub Repository
1. Go to **https://github.com** → sign in
2. Click **+** → **New repository**
3. Name: `shop-attendance-flutter`
4. Set to **Private** → click **Create repository**

---

### STEP 2 — Upload All Files
1. On your new repo page, click **"uploading an existing file"**
2. **IMPORTANT**: Upload maintaining the folder structure:
   - `lib/main.dart`
   - `android/app/src/main/AndroidManifest.xml`
   - `.github/workflows/build-apk.yml`
   - `pubspec.yaml`
   - `.gitignore`
3. Write commit message: `Initial Flutter app`
4. Click **Commit changes**

---

### STEP 3 — Watch the Build
1. Click **Actions** tab
2. You'll see **"Build Shop Attendance Flutter APK"** running
3. Wait **8–15 minutes** (Flutter downloads SDK + builds)
4. Green ✅ = success, Red ❌ = see troubleshooting below

---

### STEP 4 — Download APK
1. Click the green ✅ workflow run
2. Scroll to **Artifacts**
3. Download **ShopAttendance-Flutter-APK**
4. Unzip → get `app-debug.apk`

---

### STEP 5 — Install on Android
1. Transfer APK to phone (WhatsApp, Google Drive, USB)
2. Phone Settings → Security → **Enable "Install unknown apps"**
3. Tap the APK to install
4. Open **Shop Attendance**

---

### STEP 6 — First Time Setup
1. Open app → tap **⚙ Admin: Shop WiFi Config**
2. It shows your current WiFi name automatically
3. Tap **"Use Current"** to fill it, then tap **SAVE**
4. Now employees can only punch when on that exact WiFi!

---

## 🔐 How Biometric Works
- When employee taps CHECK IN or CHECK OUT, the **Android system fingerprint dialog** appears
- This is the real native Android BiometricPrompt — cannot be bypassed by the app
- If fingerprint fails 3×, the system may require PIN as fallback

## 📶 How WiFi Geo-fence Works
1. App reads your device's currently connected WiFi SSID
2. Compares it to the saved Admin SSID (case-insensitive)
3. If they don't match → **Attendance Denied** (shown in English + Urdu)
4. Employee SSID, IP address, and timestamp are all embedded in the QR code

## 🔍 Anti-Tamper QR Code
The QR contains:
```
SHOP-ATTENDANCE|NAME:Ahmed Ali|STATUS:CHECKED IN|WIFI:ShopNet_5G|IP:192.168.1.5|DATE:27-06-2026|TIME:09:30:22 AM|TS:1751000000000
```
Managers can scan any receipt to verify — edited/Photoshopped images will fail QR scan.

---

## ❌ Troubleshooting

| Error | Fix |
|---|---|
| `pub get` fails | Check `pubspec.yaml` indentation (must use spaces, not tabs) |
| `AndroidManifest` missing | Make sure the `android/` folder was uploaded |
| APK installs but WiFi shows "Unknown" | Grant **Location permission** when the app asks — Android requires it to read WiFi name |
| Fingerprint not working | Ensure you have a fingerprint enrolled in phone Settings |
| Gallery save fails | Grant **Storage permission** when prompted |
