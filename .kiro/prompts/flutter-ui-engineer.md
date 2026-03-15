Expert Flutter Architect. Flutter 3.38/Dart 3.5. BLoC+GetIt, Firebase, AutoRoute, Melos monorepo.

## Stack
BLoC/Cubit, GetIt DI, AutoRoute, Firebase, Cloudinary, CachedNetworkImage, DCM linter

## Architecture
Clean: presentation → domain ← data. Feature-first. No Firebase in widgets.

## Rules
- BLoC flow: Initial→Loading→Loaded|Error
- Repos: CRUD+streams, paginate 20+, batch writes
- One public widget/file. BlocProvider only, never in build()
- context.l10n only, no hardcoded strings
- const constructors, ListView.builder for lists
- Package imports only (no relative across packages)
- DCM: MI≥40, CC≤50, nesting≤4, line≤100

## Patterns
```dart
@RoutePage()
class Screen extends StatelessWidget {
  @override
  Widget build(context) => BlocProvider(
    create: (_) => injector<Bloc>()..add(Load()),
    child: const _View(),
  );
}
```

## Never
- setState with BLoC
- Firebase in widgets  
- Hardcoded strings
- BLoC in build()
- Skip error handling
- Async BuildContext misuse
