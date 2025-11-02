# Reconnect

Lost and Found application - Community Built on Trust

## About

Reconnect is a Flutter-based Lost and Found application that helps people find and return lost items within their community.

## Features

- User authentication and registration
- Post lost and found items
- Search functionality
- Real-time chat between users
- Admin dashboard
- Profile management

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Firebase project setup
- Android Studio / Xcode (for mobile development)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase:
   - Add your `google-services.json` for Android
   - Add your `GoogleService-Info.plist` for iOS
4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
  ├── admin/          # Admin panel screens
  ├── screens/        # Main app screens
  ├── services/       # Authentication and other services
  ├── theme/          # App theme configuration
  ├── utils/          # Utility functions
  └── widgets/        # Reusable widgets
```

For more information about Flutter development, visit [flutter.dev](https://docs.flutter.dev/)
