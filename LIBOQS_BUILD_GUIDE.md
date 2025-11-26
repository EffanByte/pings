# Building liboqs for Android ARM64-v8a on Windows (Native, No WSL)

## Quick Summary
This guide explains how to compile liboqs for Android ARM64-v8a **directly on Windows** (no WSL needed), then integrate it into your Flutter Gradle build.

## Prerequisites

Install on Windows:
1. **Android NDK** (already have at `C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973`)
2. **CMake** (download from https://cmake.org/download/)
   - Add to PATH during installation (so `cmake` is available in cmd.exe)
3. **Ninja** (optional but faster; download from https://github.com/ninja-build/ninja/releases)
   - Extract and add to PATH, or let CMake use "Unix Makefiles" generator (slower)
4. **Git** (for Windows; https://git-scm.com/download/win)
   - Add to PATH during installation

Verify installations:
```cmd
cmake --version
ninja --version
git --version
```

## Method 1: Automated Build Script (Recommended)

I've created a batch script: `build_liboqs_android_windows.bat`

**Run it from the project root:**

```cmd
cd D:\IS-Project\pings
build_liboqs_android_windows.bat
```

The script will:
1. Clone liboqs from GitHub (or use existing clone)
2. Configure CMake with the Android NDK toolchain
3. Build liboqs for ARM64-v8a
4. Output the path to `liboqs.so`
5. Tell you how to copy it to the Android project

**Expected output:**
```
...
[100%] Built target oqs
Build successful!
Found: D:\IS-Project\pings\liboqs\build_android_arm64-v8a\liboqs\liboqs.so

===== BUILD COMPLETE =====
Output: D:\IS-Project\pings\liboqs\build_android_arm64-v8a\liboqs\liboqs.so

Next steps:
1. Copy liboqs.so to your Android project:
   Copy-Item "..." -Destination "...\pings\android\app\src\main\jniLibs\arm64-v8a\liboqs.so"

2. Build the Flutter app:
   cd D:\IS-Project\pings\android
   gradlew assembleDebug
```

## Method 2: Manual Step-by-Step Build (for understanding or debugging)

### Step 1: Clone liboqs

```cmd
cd D:\IS-Project\pings
git clone --depth 1 https://github.com/open-quantum-safe/liboqs.git
cd liboqs
```

### Step 2: Configure with CMake

```cmd
REM Set NDK path
set NDK=C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973

REM Create build directory
mkdir build_android_arm64
cd build_android_arm64

REM Run CMake with Android toolchain
cmake .. ^
  -G "Ninja" ^
  -DCMAKE_TOOLCHAIN_FILE="%NDK%\build\cmake\android.toolchain.cmake" ^
  -DANDROID_ABI=arm64-v8a ^
  -DANDROID_PLATFORM=android-21 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_SHARED_LIBS=ON
```

If Ninja is not installed, replace `-G "Ninja"` with `-G "Unix Makefiles"` (slower but works):
```cmd
cmake .. ^
  -G "Unix Makefiles" ^
  -DCMAKE_TOOLCHAIN_FILE="%NDK%\build\cmake\android.toolchain.cmake" ^
  ...
```

### Step 3: Build

```cmd
cmake --build . --config Release
```

This will take **2-10 minutes** depending on your CPU.

### Step 4: Verify Output

```cmd
dir /s liboqs.so
```

You should see:
```
D:\IS-Project\pings\liboqs\build_android_arm64\liboqs\liboqs.so
```

### Step 5: Copy to Android Project

```cmd
REM Create jniLibs directories if they don't exist
mkdir D:\IS-Project\pings\android\app\src\main\jniLibs\arm64-v8a

REM Copy liboqs.so
copy liboqs\liboqs.so D:\IS-Project\pings\android\app\src\main\jniLibs\arm64-v8a\
```

Verify:
```cmd
dir D:\IS-Project\pings\android\app\src\main\jniLibs\arm64-v8a\
```

Should show `liboqs.so`.

## Step 6: Update CMakeLists.txt (if needed)

The CMakeLists.txt in `android/app/src/main/cpp/CMakeLists.txt` needs to find `liboqs.so`. Update it to include headers:

```cmake
cmake_minimum_required(VERSION 3.4.1)
project(falcon_bridge)

add_library(falcon_bridge SHARED
    falcon_bridge.c
)

# Find liboqs library
find_library(OQS_LIB oqs REQUIRED)

# Find liboqs headers (copy them to android/app/src/main/cpp/oqs_include/ first, or adjust path)
# Option A: If you have oqs header files available
target_include_directories(falcon_bridge PRIVATE
    ${CMAKE_SOURCE_DIR}/oqs_include
)

# Option B: If headers are in NDK sysroot or system paths (may work automatically)

target_link_libraries(falcon_bridge PRIVATE ${OQS_LIB})
```

**To get the headers**, copy them from the liboqs source:

```cmd
REM Copy oqs headers
mkdir D:\IS-Project\pings\android\app\src\main\cpp\oqs_include
xcopy /E /I D:\IS-Project\pings\liboqs\liboqs\include\oqs D:\IS-Project\pings\android\app\src\main\cpp\oqs_include\oqs
```

## Step 7: Build the Flutter App

```cmd
cd D:\IS-Project\pings\android
gradlew assembleDebug
```

Gradle will:
1. Compile `falcon_bridge.c` using CMake
2. Link against `liboqs.so` from `jniLibs/arm64-v8a/`
3. Package both libraries into the APK

## Troubleshooting

### CMake: "Could not find Android NDK"
- Verify NDK path is correct: `dir C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973`
- Update script/command with correct path

### Ninja: "command not found"
- Install Ninja from https://github.com/ninja-build/ninja/releases
- Or use CMake generator "Unix Makefiles" instead (slower)

### Build fails with "oqs.h not found"
- Ensure you copied headers to `android/app/src/main/cpp/oqs_include/` (Step 6)
- Or update CMakeLists.txt `target_include_directories()` to point to header location

### liboqs.so not found during Gradle build
- Verify file exists: `dir D:\IS-Project\pings\android\app\src\main\jniLibs\arm64-v8a\liboqs.so`
- Ensure CMakeLists.txt uses `find_library(OQS_LIB oqs)` (note: search name is `oqs`, not `liboqs`)

### Build succeeds but app crashes at runtime with "libfalcon_bridge.so not found"
- Ensure you built for the same ABI as your test device
- For emulator: use an ARM64 emulator image, or rebuild for x86_64

## Building for Multiple ABIs

To support more devices, build for additional ABIs:

```cmd
REM Build for armeabi-v7a (32-bit ARM)
cd D:\IS-Project\pings\liboqs
mkdir build_android_armeabi-v7a
cd build_android_armeabi-v7a
cmake .. ^
  -G "Ninja" ^
  -DCMAKE_TOOLCHAIN_FILE="%NDK%\build\cmake\android.toolchain.cmake" ^
  -DANDROID_ABI=armeabi-v7a ^
  -DANDROID_PLATFORM=android-21 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release
copy liboqs\liboqs.so D:\IS-Project\pings\android\app\src\main\jniLibs\armeabi-v7a\

REM Build for x86_64 (emulator/x86 devices)
cd D:\IS-Project\pings\liboqs
mkdir build_android_x86_64
cd build_android_x86_64
cmake .. ^
  -G "Ninja" ^
  -DCMAKE_TOOLCHAIN_FILE="%NDK%\build\cmake\android.toolchain.cmake" ^
  -DANDROID_ABI=x86_64 ^
  -DANDROID_PLATFORM=android-21 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release
copy liboqs\liboqs.so D:\IS-Project\pings\android\app\src\main\jniLibs\x86_64\
```

## Summary

1. Run `build_liboqs_android_windows.bat` from project root
2. Copy `liboqs.so` to `android/app/src/main/jniLibs/arm64-v8a/`
3. Copy oqs headers to `android/app/src/main/cpp/oqs_include/`
4. Run `gradlew assembleDebug` from `android/` directory
5. Done! APK will include both `libfalcon_bridge.so` and `liboqs.so`

## Next Steps

After successful build and APK deployment:
- Test the app on a real ARM64 device or ARM64 emulator
- Verify Falcon-512 signing works (check Logcat logs)
- Implement instructor-side verification (see next section of your project)
