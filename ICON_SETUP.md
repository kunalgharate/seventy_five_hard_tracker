# App Icon Setup Guide

This guide explains how to generate and update app icons for all Android versions using `flutter_launcher_icons`.

## Overview

The app uses `flutter_launcher_icons` package to automatically generate app icons for:
- **Android 7.1 and below** (API 25-): Legacy launcher icons
- **Android 8.0 to 11** (API 26-30): Adaptive icons with background and foreground layers
- **Android 12+** (API 31+): Themed icons with monochrome support

## Icon Requirements

### Source Icon
- **Location**: `assets/icons/logo.png`
- **Recommended Size**: 1024x1024 pixels
- **Format**: PNG with transparency
- **Design**: Should work well on both light and dark backgrounds

### Design Guidelines
- Keep important content within the safe zone (center 66% of the icon)
- Avoid placing critical elements near edges (they may be masked on some devices)
- Test on both light and dark backgrounds
- Ensure the icon is recognizable at small sizes

## Configuration Files

### 1. flutter_launcher_icons.yaml
Main configuration file for icon generation:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icons/logo.png"
  
  # Adaptive icons for Android 8.0+ (API 26+)
  adaptive_icon_background: "#FFA726"
  adaptive_icon_foreground: "assets/icons/logo.png"
  
  # Support for Android 12+ (API 31+)
  adaptive_icon_monochrome: "assets/icons/logo.png"
  
  # Minimum SDK version
  min_sdk_android: 21
```

### 2. pubspec.yaml
The configuration is also embedded in `pubspec.yaml` under the `flutter_launcher_icons` section.

## How to Generate Icons

### First Time Setup
```bash
# 1. Ensure your logo file exists
ls assets/icons/logo.png

# 2. Install dependencies
flutter pub get

# 3. Generate icons
dart run flutter_launcher_icons
```

### Updating Icons

When you want to change the app icon:

```bash
# 1. Replace the logo file
# Place your new icon at: assets/icons/logo.png

# 2. (Optional) Update background color in flutter_launcher_icons.yaml
# Change adaptive_icon_background: "#FFA726" to your preferred color

# 3. Regenerate icons
dart run flutter_launcher_icons

# 4. Clean and rebuild
flutter clean
flutter pub get
flutter build apk
```

## Generated Icon Files

After running the generator, icons are created in:

### Legacy Icons (Android 7.1 and below)
```
android/app/src/main/res/
├── mipmap-hdpi/ic_launcher.png
├── mipmap-mdpi/ic_launcher.png
├── mipmap-xhdpi/ic_launcher.png
├── mipmap-xxhdpi/ic_launcher.png
└── mipmap-xxxhdpi/ic_launcher.png
```

### Adaptive Icons (Android 8.0+)
```
android/app/src/main/res/
├── mipmap-hdpi/ic_launcher_foreground.png
├── mipmap-mdpi/ic_launcher_foreground.png
├── mipmap-xhdpi/ic_launcher_foreground.png
├── mipmap-xxhdpi/ic_launcher_foreground.png
├── mipmap-xxxhdpi/ic_launcher_foreground.png
└── mipmap-anydpi-v26/ic_launcher.xml
```

### Themed Icons (Android 12+)
```
android/app/src/main/res/
├── drawable/ic_launcher_monochrome.xml
└── values/colors.xml (background color)
```

## Customization Options

### Change Background Color
Edit `flutter_launcher_icons.yaml`:
```yaml
adaptive_icon_background: "#YOUR_COLOR_HEX"
```

### Use Different Images
You can use separate images for different layers:
```yaml
flutter_launcher_icons:
  android: true
  image_path: "assets/icons/legacy_icon.png"  # For old Android
  adaptive_icon_background: "#FFA726"
  adaptive_icon_foreground: "assets/icons/foreground.png"  # For adaptive
  adaptive_icon_monochrome: "assets/icons/monochrome.png"  # For Android 12+
```

### Platform-Specific Icons
```yaml
flutter_launcher_icons:
  android: true
  ios: true  # Enable if you want iOS icons too
  image_path: "assets/icons/logo.png"
  image_path_android: "assets/icons/android_logo.png"  # Android-specific
  image_path_ios: "assets/icons/ios_logo.png"  # iOS-specific
```

## Testing Icons

### Test on Different Android Versions
1. **Android 7.1 and below**: Check legacy icon appearance
2. **Android 8.0-11**: Test adaptive icon with different launcher shapes (circle, square, rounded square)
3. **Android 12+**: Test themed icon in light and dark modes

### Test on Different Launchers
- Google Pixel Launcher
- Samsung One UI
- OnePlus OxygenOS
- Xiaomi MIUI
- Stock Android

### Visual Testing Checklist
- [ ] Icon is clear and recognizable at small sizes
- [ ] Icon works on light backgrounds
- [ ] Icon works on dark backgrounds
- [ ] Adaptive icon looks good in all shapes (circle, square, rounded)
- [ ] Themed icon (monochrome) is visible and clear
- [ ] No important content is cut off by launcher masks

## Troubleshooting

### Icons Not Updating
```bash
# Clean everything and rebuild
flutter clean
rm -rf build/
dart run flutter_launcher_icons
flutter pub get
flutter build apk --release
```

### Wrong Icon Showing
- Uninstall the app completely from device
- Clear launcher cache (restart device)
- Reinstall the app

### Icon Looks Blurry
- Ensure source image is at least 1024x1024 pixels
- Use PNG format with high quality
- Avoid JPEG format

### Background Color Not Applied
- Check `flutter_launcher_icons.yaml` syntax
- Ensure color is in hex format: `"#RRGGBB"`
- Regenerate icons after changing color

## Best Practices

1. **Use High-Resolution Source**: Always start with 1024x1024px or higher
2. **Test Early**: Generate and test icons early in development
3. **Version Control**: Commit generated icons to git for consistency
4. **Document Changes**: Keep track of icon updates in changelog
5. **Brand Consistency**: Ensure icon matches your app's branding

## Automation

### Auto-generate on Build
Add to your CI/CD pipeline:
```bash
#!/bin/bash
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

### Pre-commit Hook
Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
if git diff --cached --name-only | grep -q "assets/icons/logo.png"; then
    echo "Logo changed, regenerating icons..."
    dart run flutter_launcher_icons
    git add android/app/src/main/res/mipmap-*
fi
```

## Additional Resources

- [flutter_launcher_icons Package](https://pub.dev/packages/flutter_launcher_icons)
- [Android Adaptive Icons Guide](https://developer.android.com/guide/practices/ui_guidelines/icon_design_adaptive)
- [Material Design Icon Guidelines](https://material.io/design/iconography/product-icons.html)
- [Android 12 App Icon Changes](https://developer.android.com/about/versions/12/features#app-icons)

## Support

For issues with icon generation:
1. Check package documentation: https://pub.dev/packages/flutter_launcher_icons
2. Verify your configuration syntax
3. Ensure Flutter SDK is up to date
4. Check Android SDK tools are installed

---

**Last Updated**: January 2026
**Package Version**: flutter_launcher_icons ^0.14.1
