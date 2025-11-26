@echo off
REM Build liboqs for Android ARM64-v8a on Windows (native, no WSL)
REM Prerequisites:
REM   - Android NDK installed (e.g., C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973)
REM   - CMake installed and on PATH
REM   - Git installed and on PATH
REM   - Ninja build system installed (or use "Unix Makefiles" generator if Ninja not available)

setlocal enabledelayedexpansion

REM ===== Configuration =====
set "NDK_PATH=D:\Tools\AndroidSDK\ndk\27.0.12077973"
set "ABI=arm64-v8a"
set "ANDROID_PLATFORM=android-21"
set "BUILD_TYPE=Release"
set "LIBOQS_REPO=https://github.com/open-quantum-safe/liboqs.git"
set "BUILD_DIR=build_android_%ABI%"
REM ===== Verify prerequisites =====
echo Checking prerequisites...
where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake not found. Install CMake and add to PATH.
    exit /b 1
)
where ninja >nul 2>&1
if errorlevel 1 (
    echo WARNING: Ninja not found. Attempting to use Unix Makefiles instead.
    set "CMAKE_GENERATOR=Unix Makefiles"
) else (
    set "CMAKE_GENERATOR=Ninja"
)

if not exist "%NDK_PATH%" (
    echo ERROR: NDK not found at %NDK_PATH%
    exit /b 1
)

echo Prerequisites OK.
echo   CMake: Found
echo   NDK: %NDK_PATH%
echo   ABI: %ABI%
echo   Generator: %CMAKE_GENERATOR%

REM ===== Clone or update liboqs =====
if not exist "liboqs" (
    echo Cloning liboqs repository...
    git clone --depth 1 %LIBOQS_REPO%
) else (
    echo liboqs directory already exists. Skipping clone.
)

cd liboqs

REM ===== Create and configure build directory =====
if exist "%BUILD_DIR%" (
    echo Removing old build directory...
    rmdir /s /q "%BUILD_DIR%"
)

echo Creating build directory: %BUILD_DIR%
mkdir "%BUILD_DIR%"
cd "%BUILD_DIR%"

REM ===== Run CMake with Android NDK toolchain =====
echo Running CMake...
cmake .. ^
  -G "%CMAKE_GENERATOR%" ^
  -D CMAKE_MAKE_PROGRAM:PATH=D:\Tools\AndroidSDK\cmake\4.1.2\bin\ninja.exe ^
  -DCMAKE_TOOLCHAIN_FILE="%NDK_PATH%\build\cmake\android.toolchain.cmake" ^
  -DANDROID_ABI=%ABI% ^
  -DANDROID_PLATFORM=%ANDROID_PLATFORM% ^
  -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
  -DBUILD_SHARED_LIBS=ON ^
  -DOQS_USE_OPENSSL=OFF ^
  -DOQS_BUILD_ONLY_LIB=ON

if errorlevel 1 (
    echo ERROR: CMake configuration failed.
    exit /b 1
)

REM ===== Build =====
echo Building liboqs...
cmake --build . --config %BUILD_TYPE%

if errorlevel 1 (
    echo ERROR: Build failed.
    exit /b 1
)

echo Build successful!

REM ===== Locate and display output =====
for /r . %%f in (liboqs.so) do (
    echo Found: %%f
    set "OUTPUT_SO=%%f"
)

if not defined OUTPUT_SO (
    echo ERROR: liboqs.so not found in build directory.
    exit /b 1
)

echo.
echo ===== BUILD COMPLETE =====
echo Output: %OUTPUT_SO%
echo.
echo Next steps:
echo 1. Copy liboqs.so to your Android project:
echo    Copy-Item "%OUTPUT_SO%" -Destination "..\..\..\..\..\..\pings\android\app\src\main\jniLibs\%ABI%\liboqs.so"
echo.
echo 2. Build the Flutter app:
echo    cd D:\IS-Project\pings\android
echo    gradlew assembleDebug
echo.

endlocal
