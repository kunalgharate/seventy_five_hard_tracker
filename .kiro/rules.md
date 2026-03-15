# Rules

## Must Follow
- BLoC for state, Repository for data
- `const` constructors, package imports across packages
- Line length: 100
- Use `context.l10n` for strings
- Handle loading/success/error states

## Must NOT
- `setState` in BLoC widgets
- Firebase in widgets
- Hardcoded strings
- BLoC in `build()`
