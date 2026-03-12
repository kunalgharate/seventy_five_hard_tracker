# Quick Icon Update Guide

## To Update App Icons

### 1. Replace Logo File
```bash
# Place your new icon (1024x1024 PNG) at:
assets/icons/logo.png
```

### 2. (Optional) Change Background Color
Edit `flutter_launcher_icons.yaml`:
```yaml
adaptive_icon_background: "#FFA726"  # Change this hex color
```

### 3. Generate Icons
```bash
dart run flutter_launcher_icons
```

### 4. Clean & Rebuild
```bash
flutter clean
flutter pub get
flutter build apk
```

## What Gets Generated

✅ **Android 7.1 and below**: Legacy icons (mipmap-hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi)  
✅ **Android 8.0 to 11**: Adaptive icons with background and foreground layers  
✅ **Android 12+**: Themed monochrome icons for Material You  

## Files Modified
- `android/app/src/main/res/mipmap-*/ic_launcher.png` - Legacy icons
- `android/app/src/main/res/drawable-*/ic_launcher_foreground.png` - Adaptive foreground
- `android/app/src/main/res/drawable-*/ic_launcher_monochrome.png` - Android 12+ themed
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` - Adaptive icon config
- `android/app/src/main/res/values/colors.xml` - Background color

## Troubleshooting

**Icons not updating?**
```bash
flutter clean
rm -rf build/
dart run flutter_launcher_icons
flutter pub get
# Uninstall app from device
flutter install
```

**Need more details?** See `ICON_SETUP.md`
