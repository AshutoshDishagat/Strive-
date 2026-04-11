# 📚 Strive — AI-Powered Study Ecosystem

<p align="center">
  <img src="strive1/assets/app_icon.png" alt="Strive Logo" width="120"/>
</p>

<p align="center">
  <b>An intelligent, attention-tracking study app built with Flutter & Firebase</b><br/>
  Helping students stay focused — with parental oversight and AI assistance.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Firebase-Enabled-orange?logo=firebase" />
  <img src="https://img.shields.io/badge/Gemini_AI-Powered-green?logo=google" />
  <img src="https://img.shields.io/badge/Platform-Android-brightgreen?logo=android" />
</p>

---

## 📥 Download

[![Download Strive](https://img.shields.io/badge/Download-Latest_APK-blue?style=for-the-badge&logo=android)](https://github.com/AshutoshDishagat/Strive-/releases/latest)

> [!TIP]
> **New to Strive?** Download the latest release above and install it on your Android device to get started immediately.

---

## ✨ Features

### 👨‍🎓 Student Side
- **Focus Mode** — Locks the device into study mode using a foreground service
- **Attention Tracking** — Uses the front camera + ML Kit to detect if the student is looking at the screen
- **AI Tutor** — Powered by Google Gemini, students can ask study-related questions
- **Study Reports** — View session history with duration, focus score, and exportable PDF reports
- **Brain Games** — Mini games (Sudoku, Tango, Zip, Patches) to keep the mind sharp
- **DND Mode** — Automatically silences notifications during study sessions

### 👨‍👩‍👧 Parent Side
- **Remote Study Session Trigger** — Parents can start a study session on the student's device remotely
- **App Blocking** — Parents can select specific apps to block during a session
- **Live Monitoring** — View student focus stats and session history
- **Account Linking** — Securely link parent and student accounts via a unique code

---

## 🛠️ Tech Stack

| Technology | Usage |
|---|---|
| **Flutter** | Cross-platform UI framework |
| **Firebase Auth** | User authentication (Email + Google Sign-In) |
| **Cloud Firestore** | Real-time database for sessions & linking |
| **Firebase Cloud Messaging (FCM)** | Push notifications to trigger remote study sessions |
| **Google ML Kit** | Face detection for attention tracking |
| **Google Gemini AI** | AI Tutor chat feature |
| **SQLite (sqflite)** | Local session data storage |
| **flutter_foreground_task** | Background focus mode service |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `>=3.0.0`
- Android Studio or VS Code with Flutter extension
- A Firebase project (see setup below)
- A Google Gemini API key

---

### 1. Clone the Repository

```bash
git clone https://github.com/AshutoshDishagat/Strive-.git
cd Strive-/strive1
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup ⚠️

> This app requires Firebase — you must set it up with your own credentials.

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project
2. Add an **Android app** with package name: `com.example.strive1`
3. Download `google-services.json` and place it in:
   ```
   strive1/android/app/google-services.json
   ```
4. Enable the following Firebase services:
   - **Authentication** (Email/Password + Google Sign-In)
   - **Cloud Firestore**
   - **Firebase Cloud Messaging (FCM)**

### 4. Gemini API Key ⚠️

1. Get a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Open `strive1/lib/features/gemini/views/tutor_chat_view.dart`
3. Replace the placeholder with your key:
   ```dart
   final model = GenerativeModel(model: 'gemini-pro', apiKey: 'YOUR_API_KEY_HERE');
   ```

### 5. Run the App

```bash
flutter run
```

---

## 📂 Project Structure

```
strive1/
├── lib/
│   ├── core/
│   │   ├── db/               # SQLite database helper
│   │   ├── services/         # Auth, Firestore, Background services
│   │   ├── theme/            # App colors and theme
│   │   └── widgets/          # Shared widgets
│   ├── features/
│   │   ├── auth/             # Login, Register, Forgot Password
│   │   ├── focus/            # Focus mode, attention tracking
│   │   ├── games/            # Brain games (Sudoku, Tango, etc.)
│   │   ├── gemini/           # AI Tutor chat
│   │   ├── home/             # Student home screen
│   │   ├── parent/           # Parent dashboard & controls
│   │   ├── profile/          # User profile & settings
│   │   └── reports/          # Session reports & PDF export
│   ├── models/               # Data models (Session, UserProfile)
│   └── main.dart             # App entry point
├── android/                  # Android native configuration
├── assets/                   # Images and icons
└── pubspec.yaml              # Dependencies
```

---

## ⚙️ Configuration

To build this project from source, you must provide your own API credentials:

1.  **Firebase**: Place your `google-services.json` in `strive1/android/app/`.
2.  **Gemini AI**: Add your API key in `lib/features/gemini/views/tutor_chat_view.dart`.

> [!WARNING]
> Accessing the **App Blocking** and **Foreground Focus** features requires high-level Android permissions (Usage Access, Overlay, and Camera).

---

## ⚠️ Important Notes

- `google-services.json` is **NOT included** in this repo.
- The **Gemini API key** is not included. 
- Tested on **Android** — iOS support may require additional configuration.

---

## 📄 License

This project was developed as a **Final Year Project**. Feel free to use it for educational purposes.

---

## 👨‍💻 Developer

**Ashutosh Dishagat**  
Final Year BCA Student  
GitHub: [@AshutoshDishagat](https://github.com/AshutoshDishagat)