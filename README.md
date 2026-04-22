# 📚 Strive — AI-Powered Study Ecosystem

<p align="center">
  <img src="strive1/assets/a.png" alt="Strive Old Logo" width="120"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="strive1/assets/app_icon.png" alt="Strive New Logo" width="120"/>
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
- **Focus Mode** — Locks the device into study mode using a foreground service.
- **Attention Tracking** — Uses the front camera + ML Kit to detect if the student is looking at the screen.
- **AI Tutor** — Powered by Google Gemini, students can ask study-related questions.
- **Study Reports** — View session history with focus scores and exportable PDF reports.
- **Brain Games** — Mini games to keep the mind sharp during breaks.

### 👨‍👩‍👧 Parent Side
- **Remote Study Trigger** — Start a study session on the student's device remotely via FCM.
- **App Blocking** — Select specific apps to restrict on the child's device.
- **Live Monitoring** — View real-time focus stats and session history.
- **Account Linking** — Simple one-time linking via a unique guardian code.

---

## 🚀 Getting Started (For Developers)

Follow these steps to clone and run the project locally.

### 1. Clone the Repository
```bash
git clone https://github.com/AshutoshDishagat/Strive-.git
cd Strive-/strive1
```

### 2. Install Flutter Dependencies
Ensure you have [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
```bash
flutter pub get
```

### 3. Firebase Configuration ⚠️ (MANDATORY)
This project **requires** its own Firebase instance to function. You MUST provide your own config file.

1.  Create a project in the [Firebase Console](https://console.firebase.google.com/).
2.  Add an **Android App** with the package name: `com.example.strive1`.
3.  Download the `google-services.json` file.
4.  Place it in the following directory:  
    `strive1/android/app/google-services.json`
5.  **Enable these Services** in your Firebase Console:
    - **Authentication** (Email/Password + Google Sign-In)
    - **Cloud Firestore**
    - **Firebase Cloud Messaging (FCM)**

### 4. Google Gemini AI Setup ⚠️
The AI Tutor requires a Gemini API Key.
1.  Generate a free key at [Google AI Studio](https://aistudio.google.com/app/apikey).
2.  Open `lib/core/services/gemini_service.dart`.
3.  Find the `_apiKey` variable at the top and paste your key:
    ```dart
    static const String _apiKey = 'YOUR_API_KEY_HERE';
    ```

### 5. Run the App
Connect an Android device or emulator and run:
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
│   │   ├── services/         # Auth, Firestore, Gemini, & Background services
│   │   ├── theme/            # App colors & theme logic
│   │   └── widgets/          # Shared UI components
│   ├── features/
│   │   ├── auth/             # Login, Signup, & Password Recovery
│   │   ├── focus/            # Real-time attention tracking & blocking
│   │   ├── games/            # Educational mini-games
│   │   ├── gemini/           # AI Tutor chat interface
│   │   ├── parent/           # Guardian dashboard & remote controls
│   │   └── reports/          # Session analytics & PDF generation
│   ├── models/               # Shared Data Models
│   └── main.dart             # Application Entry Point
├── android/                  # Native Android configuration
├── assets/                   # App icons & static media
└── pubspec.yaml              # Dependencies & Asset configuration
```

---

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Local DB**: SQLite (via `sqflite`)
- **Backend**: Firebase (Auth, Firestore, FCM)
- **AI**: Google Gemini Pro (via `google_generative_ai`)
- **ML**: Google ML Kit (Face Detection)

---

## 📄 License
This project was developed as a **Final Year Project**. Feel free to use it for educational purposes.

## 👨‍💻 Developer
**Ashutosh Dishagat**  
Final Year BCA Student  
GitHub: [@AshutoshDishagat](https://github.com/AshutoshDishagat)