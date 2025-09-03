# 75 Hard Challenge Tracker

A Flutter app to help users track their 75 Hard personal challenge with custom daily tasks, progress tracking, and motivational features.

#Play Store link : https://play.google.com/store/apps/details?id=com.seventyfive.hard.challenge&hl=en-US&ah=kv1OY6af0PDN2jAVgNwd8HGqf3Y

## Features

### 🎯 Core Features
- **Custom Challenge Setup**: Create up to 10 personalized daily tasks
- **75-Day Progress Tracking**: Visual calendar with completion status
- **Automatic Reset**: Miss any task = automatic reset to Day 1
- **Session History**: Track all previous attempts and failure points
- **Local Storage**: All data stored locally using Hive database

### 📱 User Experience
- **Material Design**: Clean, modern Android-focused UI
- **Progress Statistics**: Current streak, best streak, completion percentage
- **Daily Journal**: Add personal notes for each day
- **Completion Certificate**: Celebration screen for finishing 75 days

### 🔔 Notifications & Reminders
- **Daily Motivation**: 8AM motivational quotes (online + offline backup)
- **Custom Task Reminders**: Set individual reminder times for each challenge
- **Reset Notifications**: Automatic alerts when challenge resets
- **Completion Celebration**: Special notification for finishing

### 📊 Progress Tracking
- **Visual Calendar**: Color-coded days (green = completed, red = failed)
- **Statistics Dashboard**: Current day, completion rate, streaks
- **History View**: All previous sessions with failure analysis
- **Challenge Breakdown**: See which specific tasks caused failures

## Technical Implementation

### Architecture
- **State Management**: BLoC pattern with flutter_bloc
- **Local Database**: Hive for offline data storage
- **Notifications**: flutter_local_notifications with timezone support
- **UI Framework**: Material Design 3

### Key Dependencies
```yaml
dependencies:
  flutter_bloc: ^8.1.3          # State management
  hive: ^2.2.3                  # Local database
  hive_flutter: ^1.1.0          # Flutter integration
  flutter_local_notifications: ^17.2.2  # Local notifications
  table_calendar: ^3.1.2        # Calendar widget
  http: ^1.2.2                  # API calls for quotes
  permission_handler: ^11.3.1   # Android permissions
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio or VS Code
- Android device/emulator for testing

### Installation
1. Clone the repository:
```bash
git clone <repository-url>
cd seventy_five_hard_tracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate Hive adapters:
```bash
flutter packages pub run build_runner build
```

4. Run the app:
```bash
flutter run
```

## App Flow

### 1. Onboarding
- User creates 1-10 custom daily challenges
- Examples: "Workout 45min", "Read 10 pages", "Drink 1 gallon water"
- Challenges are locked once the session starts

### 2. Daily Tracking
- Calendar view showing all 75 days
- Check off completed tasks each day
- Add optional journal notes
- View progress statistics

### 3. Automatic Reset Logic
- App checks for missed days automatically
- If any task is incomplete, challenge resets to Day 1
- Failure reason and missed tasks are recorded
- User receives notification about reset

### 4. Completion
- After 75 consecutive successful days
- Celebration screen with achievement notification
- Session saved to history as completed

### 5. History & Analytics
- View all previous attempts
- See failure points and reasons
- Track improvement over time
- Analyze which tasks are most challenging

## Notification Features

### Daily Motivation (8:00 AM)
- Inspirational quotes to start the day
- Online API with offline fallback
- Customizable motivational messages

### Task Reminders
- Individual reminder times for each challenge
- User can enable/disable per task
- Customizable notification times

### System Notifications
- Challenge reset alerts
- Completion celebrations
- Daily progress reminders

## Data Storage

### Local Database (Hive)
- **Challenge Sessions**: Track each 75-day attempt
- **Daily Progress**: Store completion status for each day
- **Settings**: User preferences and configurations

### Data Models
- `Challenge`: Individual task with reminder settings
- `ChallengeSession`: 75-day session with metadata
- `DailyProgress`: Daily completion status and journal notes

## Privacy & Security
- **No Account Required**: Completely local app
- **No Data Collection**: All data stays on device
- **Offline Capable**: Works without internet connection
- **Local Notifications**: No external notification services

## Customization Options

### Settings Screen
- Configure task reminder times
- Preview motivational quotes
- Reset current challenge (with confirmation)
- View app information and rules

### Notification Preferences
- Enable/disable daily motivation
- Set custom reminder times per task
- Control notification frequency

## Development Notes

### State Management (BLoC)
- `ChallengeBloc`: Main business logic
- Events: User actions (start session, update progress, etc.)
- States: UI states (loading, loaded, error, completed, reset)

### Database Schema
- Type-safe Hive adapters with code generation
- Efficient local storage with minimal overhead
- Automatic data migration support

### Notification System
- Timezone-aware scheduling
- Persistent notifications across app restarts
- Battery optimization friendly

## Future Enhancements

### Potential Features
- Export progress data
- Share achievements on social media
- Multiple challenge templates
- Progress charts and analytics
- Photo attachments for daily progress
- Integration with fitness trackers
- Community features (optional)

### Technical Improvements
- Background sync capabilities
- Enhanced offline quote database
- Performance optimizations
- Accessibility improvements
- iOS support expansion

## Contributing

This is a personal challenge tracker focused on simplicity and privacy. The app is designed to work completely offline with no external dependencies beyond motivational quote APIs.

## License

This project is created for educational and personal use. Feel free to modify and adapt for your own 75 Hard challenge journey!

---

**Remember**: The 75 Hard Challenge is about mental toughness and consistency. This app is just a tool - your commitment and discipline are what matter most! 💪
