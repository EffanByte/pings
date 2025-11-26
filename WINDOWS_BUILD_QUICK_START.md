# Windows Native Build — Quick Start

## Compile liboqs for Android ARM64-v8a on Windows (No WSL)

### One-Liner (Recommended)

From the project root, run ONE of these:

**Option 1: Batch (cmd.exe)**
```cmd
build_liboqs_android_windows.bat
```

**Option 2: PowerShell**
```powershell
.\build_liboqs_android_windows.ps1
```

### What Happens
1. Clones liboqs from GitHub
2. Configures CMake with Android NDK toolchain
3. Builds for ARM64-v8a
4. Outputs the path to `liboqs.so`
5. Tells you exactly what to do next

### Prerequisites (Install First)

```
1. CMake         https://cmake.org/download/
2. Git for Win   https://git-scm.com/download/win
3. Ninja         https://github.com/ninja-build/ninja/releases (optional, speeds up build)
4. Android NDK   (already have: C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973)
```

Make sure all are on your PATH (or can be found from cmd/PowerShell).

### After Build Completes

The script will tell you to:

1. **Create jniLibs directory:**
   ```cmd
   mkdir android\app\src\main\jniLibs\arm64-v8a
   ```

2. **Copy liboqs.so:**
   ```cmd
   copy liboqs\build_android_arm64-v8a\liboqs\liboqs.so ^
         android\app\src\main\jniLibs\arm64-v8a\
   ```

3. **Copy oqs headers:**
   ```cmd
   mkdir android\app\src\main\cpp\oqs_include
   xcopy /E /I liboqs\liboqs\include\oqs android\app\src\main\cpp\oqs_include\oqs
   ```

4. **Build Flutter app:**
   ```cmd
   cd android
   gradlew assembleDebug
   ```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "cmake: command not found" | Install CMake and add to PATH |
| "git: command not found" | Install Git for Windows |
| "Build fails with linker error" | Ensure liboqs.so is in `jniLibs/arm64-v8a/` |
| "oqs.h not found" | Copy headers to `android/app/src/main/cpp/oqs_include/` |
| Build takes >20 min | Ninja is slower on Windows; install Ninja to speed up |

### Why This Works

- **CMake with Android.toolchain.cmake** = tells compiler to target ARM64
- **NDK has C/C++ compiler** = CMake uses it to build liboqs for Android
- **No WSL needed** = all native Windows tools

### Support Multiple ABIs

After ARM64 works, optionally build for 32-bit and x86:

```cmd
REM Edit build_liboqs_android_windows.bat:
REM Change ABI to "armeabi-v7a" and run
REM Then copy to jniLibs\armeabi-v7a\

REM Or edit and run script 3 times with different ABIs:
REM - arm64-v8a (modern phones)
REM - armeabi-v7a (older phones)
REM - x86_64 (emulator/x86 devices)
```

### Full Details

See `LIBOQS_BUILD_GUIDE.md` in this directory.
