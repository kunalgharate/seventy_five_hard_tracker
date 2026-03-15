# Flutter Monorepo Quick Guide

**Stack**: Flutter 3.38.3 · Dart 3.5.0 · Firebase · BLoC · Line: 100

## Architecture
Clean: presentation → domain ← data. BLoC for state, Repository for data.

## Must Follow (P1)
- BLoC only, no `setState` in BLoC widgets
- Repository pattern, no Firebase in widgets  
- Use `context.l10n` for strings
- Package imports across packages
- `const` constructors
- Handle error states

## Pattern
```dart
class XBloc extends Bloc<XEvent, XState> {
  final XRepo _repo;
  XBloc({required XRepo repo}) : _repo = repo, super(XInitial());
}
```

## Commands
```bash
flutter run --flavor dev -t lib/main_dev.dart
melos run check
dart run build_runner build --delete-conflicting-outputs
```
