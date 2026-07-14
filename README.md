# Millie Control

The remote control interface for Millie Bot. This Flutter app runs on a separate tablet, providing joystick control, live camera feed, map visualization, waypoint management, and AI-powered chat.

![Flutter](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-Educational_Use-blue)

---

### Learn more at **https://DreamCloudClub.org**

This project is part of the **Millie Bot** ecosystem — an educational robotics platform for learning ROS, Flutter, and AI integration:

| Project | Description |
|---------|-------------|
| **[Millie Bot](https://github.com/DreamCloudClub/millie_bot)** | ROS2 package - navigation, sensors, motor control |
| **[Millie AI](https://github.com/DreamCloudClub/millie_ai)** | Expressive face and voice AI for the robot |
| **Millie Control** | This app — remote control interface for Millie Bot |

---

## What This App Does

Millie Control is the operator's interface to the robot. While Millie AI handles the public-facing interactions, this app lets you:

- **Drive the robot** with a virtual joystick
- **See what the robot sees** via live camera feed
- **Navigate the map** — view position, set goals, manage waypoints
- **Build workflows** — create multi-step task sequences
- **Chat with AI** — conversational control with function calling
- **Configure the robot** — agents, memories, maps, system controls

## Screenshots

### Camera & Joystick
![Camera](screenshots/camera.jpg)

### Map & Navigation
![Map](screenshots/map.jpg)

### Task Manager
![Tasks](screenshots/tasks.jpg)

### AI Chat
![Chat](screenshots/chat.jpg)

### Settings
![Settings](screenshots/settings.jpg)

## Features

### Camera View
- Live MJPEG video stream from OAK-D Lite camera
- Connection status indicator
- Low bandwidth mode for poor connections

### Virtual Joystick
- Smooth velocity control for manual driving
- 9 configurable quick-action buttons
- Mode controls: Launch, Start, Wander, Play/Pause, Exit
- Quick navigation buttons for favorite waypoints

### Map View
- Real-time occupancy grid from SLAM
- Robot position and orientation indicator
- Tap-to-navigate: click anywhere to send a goal
- Waypoint overlay: add, delete, navigate to saved locations
- Direction dial for setting goal orientation
- Pan and zoom controls

### Locations & Tasks
- **Points Tab**: Grid view of saved waypoints
- **Actions Tab**: AI conversation actions/prompts
- **Robot Tab**: System status and controls
- **Tasks Tab**: Workflow builder with drag-and-drop

### AI Chatbot
- Text or voice input (Whisper speech-to-text)
- GPT-4o-mini for natural language understanding
- Function calling for robot commands
- Text-to-speech responses
- Persistent conversation history

### Settings
- **Robot**: Start/stop ROS, select maps, view CPU/memory/uptime
- **Agents**: Configure AI personalities (voice, face, behavior)
- **Memory**: Manage robot memories (people, notes)
- **Camera**: Detection overlay, low bandwidth, center-on-human
- **Profile**: User profile for personalized interactions

### Safety
- Prominent E-STOP button always visible
- Shutdown and reboot controls
- Visual feedback for all operations

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  MILLIE CONTROL (Controller Tablet)              │
│                                                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Joystick │ │   Map    │ │   Chat   │ │ Settings │           │
│  │  Panel   │ │  Panel   │ │  Panel   │ │   Page   │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                  │
│       └────────────┼────────────┼────────────┘                  │
│                    │            │                               │
│            ┌───────▼───────┐    │                               │
│            │   RosBridge   │    │ OpenAI API                    │
│            │   WebSocket   │    │ (Chat/STT/TTS)                │
│            └───────┬───────┘    │                               │
└────────────────────┼────────────┼───────────────────────────────┘
                     │            │
     ws://robot:9090 │            │ HTTPS
                     ▼            ▼
┌────────────────────────────────────────────────────────────────┐
│                    MILLIE BOT (ROS2)                            │
│                                                                 │
│  /cmd_vel ───► Limiter ───► Motor Node ───► Arduino ───► Motors│
│                                                                 │
│  /map ◄─── SLAM Toolbox ◄─── Scan Filter ◄─── LiDAR            │
│                                                                 │
│  /oak/rgb ◄─── OAK-D Person Detector ◄─── Camera               │
│                                                                 │
│  Waypoints, Workflows, Agents, Actions (persistent storage)    │
└────────────────────────────────────────────────────────────────┘
                     ▲
                     │ Shared ROS topics
                     ▼
┌────────────────────────────────────────────────────────────────┐
│                    MILLIE AI (Face Tablet)                      │
│  Receives workflow commands, publishes voice state              │
└────────────────────────────────────────────────────────────────┘
```

## Network Setup

### Current Setup (TP-Link Travel Router)
The robot uses a TP-Link AX1500 travel router as a dedicated network hub:

```
┌─────────────────────────────────────────────────────────────┐
│                      NETWORK TOPOLOGY                        │
│                                                              │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐   │
│  │   Robot     │     │  TP-Link    │     │   Local     │   │
│  │  Computer   │◄───►│   AX1500    │◄───►│   WiFi      │   │
│  │ 192.168.0.157│ ETH │  (Router)   │WiFi │  (Office)   │   │
│  └─────────────┘     └─────────────┘     └─────────────┘   │
│        ▲                   ▲                                │
│        │                   │ WiFi                           │
│        ▼                   ▼                                │
│  ┌─────────────┐     ┌─────────────┐                       │
│  │    Face     │     │ Controller  │                       │
│  │   Tablet    │     │   Tablet    │                       │
│  └─────────────┘     └─────────────┘                       │
│                                                              │
│  Robot: Static IP 192.168.0.157 via Ethernet                │
│  Tablets: Connect to TP-Link WiFi "millie network 5G"       │
│  TP-Link: Bridges to local WiFi for internet                │
└─────────────────────────────────────────────────────────────┘
```

**Network Details:**
- **Robot IP**: 192.168.0.157 (static, ethernet connection)
- **TP-Link WiFi**: SSID "millie network 5G" / Password "milliebot1!"
- **Gateway**: 192.168.0.1

**Deployment:**
1. Configure TP-Link to connect to location's WiFi (via TP-Link app)
2. Robot ethernet stays at 192.168.0.157 - no configuration needed
3. Users connect tablets to "millie network 5G" and run the app

**Developer SSH Access:**
The robot also maintains a WiFi connection to the office network for remote SSH access, independent of the TP-Link network.

## Communication

### To Robot (via ROSBridge)
| Topic | Purpose |
|-------|---------|
| /cmd_vel | Velocity commands from joystick |
| /millie/mode/set | Mode switching (idle, mapping, navigating) |
| /millie/nav/goal | Navigation goals (waypoint or coordinates) |
| /millie/waypoint/save | Save current position as waypoint |
| /millie/workflow/execute | Start multi-step workflow |
| /millie/agent | Switch AI personality on face tablet |
| /person_follower/enable | Enable/disable person following |
| /wander/enable | Enable/disable exploration mode |

### From Robot (via ROSBridge)
| Topic | Purpose |
|-------|---------|
| /pose | Robot position for map display |
| /map | Occupancy grid for navigation view |
| /scan_filtered | Laser scan overlay (optional) |
| /millie/waypoints | List of saved waypoints |
| /millie/workflow/status | Workflow execution progress |
| /millie/mode/status | Current operating mode |
| /oak/rgb/image_raw | Camera feed (via MJPEG) |

### Coordination with Face Tablet
Both tablets share the same ROS topics. The controller can:
- Trigger actions that the face tablet executes
- See voice state from the face tablet
- Send mode commands that affect both apps

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.9+
- Android, iOS, Linux, macOS, Windows, or Web
- OpenAI API key (for AI chat features)
- Running Millie Bot with:
  - ROSBridge on port 9090
  - web_video_server on port 8080
  - Boot server API on port 5050 (optional, for power controls)

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

Create a `.env` file with your API key:

```env
OPENAI_API_KEY=sk-your-openai-key
```

Get your API key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

### 4. Configure robot connection

Update your robot's IP address in `lib/config/robot_config.dart`:

```dart
static const String robotIP = '192.168.0.157';  // Your robot's IP
static const int rosbridgePort = 9090;
static const int apiPort = 5050;
static const int videoPort = 8080;
```

### 5. Run the app

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point, initialization
├── config/
│   └── robot_config.dart     # Network configuration (IPs, ports)
├── pages/
│   ├── home_page.dart        # Main layout, view orchestration
│   ├── settings_page.dart    # Robot and app configuration
│   ├── locations_page.dart   # Waypoints and task management
│   └── action_editor_page.dart # Create/edit AI actions
├── services/
│   ├── openai_service.dart   # ChatGPT integration
│   ├── navigation_tools.dart # AI function calling tools
│   ├── location_service.dart # Robot location tracking
│   ├── local_cache_service.dart # Offline data persistence
│   └── button_config_service.dart # Quick button configuration
├── widgets/
│   ├── icon_rail.dart        # Left navigation bar
│   ├── video_panel.dart      # MJPEG camera feed
│   ├── map_panel.dart        # Interactive navigation map
│   ├── joystick_panel.dart   # Virtual joystick and buttons
│   ├── chatbot_panel.dart    # AI chat interface
│   ├── robot_control_panel.dart # ROS system controls
│   └── top_notification.dart # Toast notifications
└── utils/
    ├── rosbridge.dart        # WebSocket ROS communication
    ├── robot_api.dart        # HTTP API for system control
    └── constants.dart        # Colors, dimensions
```

## Usage

### Driving the Robot
1. Select **Camera** view to see the robot's perspective
2. Use the joystick to drive manually
3. The robot stops when you release the joystick

### Navigating to Waypoints
1. Select **Map** view
2. Tap any saved waypoint to navigate there
3. Or tap anywhere on the map to set a custom goal
4. Use the direction dial to set orientation

### Building Workflows
1. Go to **Locations** > **Tasks** tab
2. Drag waypoints and actions into the task queue
3. Reorder steps as needed
4. Press play to execute the workflow

### AI Chat
1. Select **Chat** view
2. Type or speak your command
3. The AI can navigate, trigger actions, and control the robot
4. Example: "Go to the kitchen and greet anyone you see"

### Emergency Stop
- The red **E-STOP** button is always visible in the left rail
- Pressing it immediately stops all motion and disables autonomous behaviors

## Platforms

| Platform | Status |
|----------|--------|
| Android | Tested |
| iOS | Supported |
| Linux | Supported |
| macOS | Supported |
| Windows | Supported |
| Web | Supported |

## Troubleshooting

### No connection to robot
- Verify robot IP in `lib/config/robot_config.dart`
- Ensure ROSBridge is running on port 9090
- Check both devices are on same network
- Try the Boot Server status endpoint: `http://192.168.0.157:5050/status`

### No camera feed
- Ensure web_video_server is running on port 8080
- Check camera topic: `/oak/rgb/image_raw`
- Try low bandwidth mode in Settings > Camera

### Joystick not responding
- Verify `/cmd_vel` topic is being published
- Check limiter_node is running on robot
- Ensure no E-STOP is active

### Map not showing
- Verify SLAM is running (mapping or navigating mode)
- Check `/map` topic is publishing
- Ensure scan_filter_node is active

## Resources and Support

### AI Services
| Service | Documentation |
|---------|---------------|
| **OpenAI Chat (GPT)** | https://platform.openai.com/docs/guides/chat |
| **OpenAI Whisper (STT)** | https://platform.openai.com/docs/guides/speech-to-text |
| **OpenAI TTS** | https://platform.openai.com/docs/guides/text-to-speech |

### Robot Communication
| Component | Documentation |
|-----------|---------------|
| **ROSBridge** | https://github.com/RobotWebTools/rosbridge_suite |
| **Nav2 Navigation** | https://docs.nav2.org/ |
| **OAK-D Lite Camera** | https://docs.luxonis.com/ |
| **Luxonis Forum** | https://discuss.luxonis.com/ |

### Flutter Development
| Resource | Link |
|----------|------|
| **Flutter SDK** | https://docs.flutter.dev/ |
| **Dart Language** | https://dart.dev/guides |
| **Flutter Packages** | https://pub.dev/ |

## License

**Educational Use Only** — Free for personal, educational, and hobbyist use. Commercial use is not permitted. See [LICENSE](LICENSE) for details.

---

Made with care by [Dream Cloud Club](https://DreamCloudClub.org)
