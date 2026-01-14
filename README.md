# Millie Control

A cross-platform Flutter app for controlling ROS-based robots with AI-powered voice interaction.

![Flutter](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-Educational_Use-blue)

---

### 🌐 Learn more at **https://DreamCloudClub.org**

This project is part of the **Millie Bot** ecosystem — an educational robotics platform for learning ROS, Flutter, and AI integration:

| Project | Description |
|---------|-------------|
| **Millie Bot** | The ROS-powered robot hardware and navigation stack |
| **Millie Control** | This app — remote control interface for Millie Bot |
| **Millie AI** | Interactive face and personality display for the robot |

*More project links coming soon!*

---

![Millie Robot](screenshots/millie_bot.JPG)

## Screenshots

### Camera & Joystick
![Camera](screenshots/camera.jpg)

### Map & Navigation
![Map](screenshots/map.jpg)

### Task Manager
![Tasks](screenshots/tasks.jpg)

### Tickets
![Tickets](screenshots/tickets.jpg)

### AI Chat
![Chat](screenshots/chat.jpg)

### Settings
![Settings](screenshots/settings.jpg)

## Features

- **Live Video Streaming** — MJPEG camera feed from the robot
- **Virtual Joystick** — Manual robot control with on-screen joystick
- **Map View** — Real-time navigation and mapping visualization
- **AI Chatbot** — Conversational robot control powered by OpenAI
  - Text and voice input (Whisper speech-to-text)
  - Text-to-speech responses
  - Function calling for robot commands
- **Locations** — Save and navigate to waypoints
- **Tickets** — Task/job management system
- **Robot Controls** — E-stop, shutdown, and reboot commands
- **Responsive Layout** — Optimized for both landscape and portrait orientations

## Platforms

Works on Android, iOS, Linux, macOS, Windows, and Web.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.9+
- A ROS robot with:
  - [rosbridge_server](http://wiki.ros.org/rosbridge_suite) running on port `9090`
  - MJPEG video stream available
  - Boot server API (optional, for power controls)
- OpenAI API key (for AI chat features)

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/DreamCloudClub/millie_control.git
cd millie_control
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment

Copy the example environment file and add your API key:

```bash
cp .env.example .env
```

Edit `.env` and add your OpenAI API key:

```
OPENAI_API_KEY=sk-your-api-key-here
```

> Get your API key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

### 4. Configure robot connection

Update the robot IP address in `lib/pages/home_page.dart`:

```dart
robotApi = RobotApi("http://YOUR_ROBOT_IP:5050");
rosBridge = RosBridge("ws://YOUR_ROBOT_IP:9090");
```

### 5. Run the app

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
├── pages/                 # Full-screen views
│   ├── home_page.dart     # Main dashboard
│   ├── settings_page.dart
│   ├── locations_page.dart
│   └── tickets_page.dart
├── services/              # External service integrations
│   ├── openai_service.dart
│   ├── location_service.dart
│   └── navigation_tools.dart
├── utils/                 # Utilities and constants
│   ├── constants.dart
│   ├── robot_api.dart
│   └── rosbridge.dart
└── widgets/               # Reusable UI components
    ├── video_panel.dart
    ├── joystick_panel.dart
    ├── map_panel.dart
    ├── chatbot_panel.dart
    └── ...
```

## License

**Educational Use Only** — This software is free for personal, educational, and hobbyist use. Commercial use is not permitted. See [LICENSE](LICENSE) for details.

---

Made with ❤️ by [Dream Cloud Club](https://DreamCloudClub.org)
