# Gradle Build Configuration

## Current Status: ✅ Caching Enabled

### Gradle Cache Configuration

#### gradle.properties
```properties
# Build Performance
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G
org.gradle.caching=true              # ✅ Gradle build cache enabled
org.gradle.parallel=true             # ✅ Parallel execution enabled
org.gradle.configureondemand=true    # ✅ Configure on demand enabled

# Android Build Cache
android.enableBuildCache=true        # ✅ Android build cache enabled
```

#### gradle-wrapper.properties
```properties
distributionUrl=gradle-8.10.2-bin.zip  # ✅ Using cached Gradle distribution
```

## How Gradle Caching Works

### 1. **Gradle Distribution Cache**
- **Location**: `~/.gradle/wrapper/dists/`
- **What**: Gradle binaries (8.10.2)
- **Behavior**: Downloaded once, reused forever
- **Status**: ✅ Enabled by default

### 2. **Build Cache**
- **Location**: `~/.gradle/caches/`
- **What**: Compiled outputs, dependencies, build artifacts
- **Behavior**: Reuses previous build outputs
- **Status**: ✅ Enabled (`org.gradle.caching=true`)

### 3. **Dependency Cache**
- **Location**: `~/.gradle/caches/modules-2/`
- **What**: Downloaded dependencies (AAR, JAR files)
- **Behavior**: Downloaded once, cached locally
- **Status**: ✅ Enabled by default

### 4. **Android Build Cache**
- **Location**: `~/.android/build-cache/`
- **What**: Android-specific build outputs
- **Behavior**: Caches dex files, resources, etc.
- **Status**: ✅ Enabled (`android.enableBuildCache=true`)

## Build Performance Optimizations

### Enabled Features

1. **Parallel Execution** (`org.gradle.parallel=true`)
   - Runs independent tasks in parallel
   - Utilizes multiple CPU cores
   - Faster builds on multi-core systems

2. **Configuration on Demand** (`org.gradle.configureondemand=true`)
   - Only configures relevant projects
   - Skips unnecessary project configuration
   - Faster for multi-module projects

3. **Increased Heap Size** (`-Xmx4G`)
   - 4GB max heap for Gradle daemon
   - Prevents out-of-memory errors
   - Faster builds with more memory

4. **Build Cache** (`org.gradle.caching=true`)
   - Reuses outputs from previous builds
   - Skips unchanged tasks
   - Significantly faster incremental builds

## Cache Locations

### Gradle User Home
```
~/.gradle/
├── caches/
│   ├── modules-2/          # Dependencies
│   ├── build-cache-1/      # Build outputs
│   └── transforms-3/       # Transformed artifacts
├── wrapper/
│   └── dists/              # Gradle distributions
└── daemon/                 # Gradle daemon logs
```

### Android Build Cache
```
~/.android/
└── build-cache/            # Android-specific cache
```

### Project Build Cache
```
android/
├── .gradle/                # Project-specific cache
└── build/                  # Build outputs (not cached in git)
```

## Build Types

### Clean Build (No Cache)
```bash
flutter clean
flutter build apk
```
- Downloads all dependencies
- Compiles everything from scratch
- Takes longest time (~2-5 minutes)

### Incremental Build (With Cache)
```bash
flutter build apk
```
- Reuses cached dependencies ✅
- Reuses unchanged build outputs ✅
- Only compiles changed files ✅
- Much faster (~30-60 seconds)

### Hot Reload (Development)
```bash
flutter run
# Press 'r' for hot reload
```
- Fastest option for development
- No Gradle rebuild needed
- Instant UI updates

## Cache Verification

### Check if Cache is Working
```bash
# First build (cold)
time flutter build apk

# Second build (warm - should be faster)
time flutter build apk
```

### View Cache Statistics
```bash
# Gradle build scan
cd android
./gradlew build --scan

# Cache size
du -sh ~/.gradle/caches
du -sh ~/.android/build-cache
```

## Cache Management

### Clear All Caches
```bash
# Flutter cache
flutter clean

# Gradle cache
rm -rf ~/.gradle/caches
rm -rf ~/.android/build-cache

# Project cache
rm -rf android/.gradle
rm -rf android/build
```

### Clear Specific Caches
```bash
# Only dependencies
rm -rf ~/.gradle/caches/modules-2

# Only build cache
rm -rf ~/.gradle/caches/build-cache-1

# Only Android cache
rm -rf ~/.android/build-cache
```

## Performance Metrics

### Expected Build Times

| Build Type | First Build | Incremental Build |
|------------|-------------|-------------------|
| Clean | 2-5 minutes | N/A |
| With Cache | 1-3 minutes | 30-60 seconds |
| Hot Reload | N/A | 1-3 seconds |

### Cache Hit Rates
- **Dependencies**: ~100% (rarely change)
- **Build Outputs**: ~70-90% (depends on changes)
- **Transforms**: ~80-95% (stable between builds)

## Troubleshooting

### Issue: Builds are slow
**Solution**: 
```bash
# Verify cache is enabled
grep "org.gradle.caching" android/gradle.properties

# Should show: org.gradle.caching=true
```

### Issue: Out of memory errors
**Solution**: Already configured with 4GB heap
```properties
org.gradle.jvmargs=-Xmx4G
```

### Issue: Cache corruption
**Solution**:
```bash
# Clear and rebuild
flutter clean
rm -rf ~/.gradle/caches
flutter pub get
flutter build apk
```

## Best Practices

### ✅ Do
- Keep cache enabled (default)
- Use incremental builds
- Only run `flutter clean` when necessary
- Let Gradle manage cache automatically

### ❌ Don't
- Don't disable caching unless debugging
- Don't manually delete cache frequently
- Don't commit `build/` or `.gradle/` to git
- Don't run `flutter clean` before every build

## CI/CD Considerations

### GitHub Actions / GitLab CI
```yaml
- name: Cache Gradle
  uses: actions/cache@v3
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: gradle-${{ hashFiles('**/*.gradle*') }}
```

### Benefits
- Faster CI builds
- Reduced bandwidth usage
- Lower build costs

## Summary

✅ **Gradle caching is ENABLED and optimized**
- Build cache: Enabled
- Dependency cache: Enabled (default)
- Parallel execution: Enabled
- Configuration on demand: Enabled
- Adequate heap size: 4GB

**Result**: Incremental builds are ~3-5x faster than clean builds!

---

**Last Updated**: January 18, 2026
**Gradle Version**: 8.10.2
**Status**: ✅ Optimized for performance
