@echo off
REM Build liboqs for Android ARM64-v8a on Windows (native, no WSL)
REM Prerequisites:
REM   - Android NDK installed (e.g., C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973)
REM   - CMake installed and on PATH
REM   - Git installed and on PATH
REM   - Ninja build system installed (or use "Unix Makefiles" generator if Ninja not available)

setlocal enabledelayedexpansion

REM ===== Configuration =====
set "ABI=arm64-v8a"
set "ANDROID_PLATFORM=android-21"
set "BUILD_TYPE=Release"
set "LIBOQS_REPO=https://github.com/open-quantum-safe/liboqs.git"
set "BUILD_DIR=build_android_%ABI%"

REM ===== Auto-detect NDK path =====
if not defined NDK_PATH (
    if defined ANDROID_NDK (
        set "NDK_PATH=%ANDROID_NDK%"
    ) else if defined ANDROID_SDK_ROOT (
        REM Find the latest NDK in ANDROID_SDK_ROOT/ndk/
        for /d %%D in ("%ANDROID_SDK_ROOT%\ndk\*") do (
            set "NDK_PATH=%%D"
        )
    ) else if defined ANDROID_HOME (
        for /d %%D in ("%ANDROID_HOME%\ndk\*") do (
            set "NDK_PATH=%%D"
        )
    ) else (
        REM Try common default location
        for /d %%D in ("%LOCALAPPDATA%\Android\sdk\ndk\*") do (
            set "NDK_PATH=%%D"
        )
    )
)

REM ===== Verify prerequisites =====
echo Checking prerequisites...
where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake not found. Install CMake and add to PATH.
    exit /b 1
)

REM Find ninja executable path
for /f "delims=" %%i in ('where ninja 2^>nul') do set "NINJA_EXE=%%i"
if not defined NINJA_EXE (
    echo WARNING: Ninja not found. Attempting to use Unix Makefiles instead.
    set "CMAKE_GENERATOR=Unix Makefiles"
    set "CMAKE_MAKE_PROGRAM="
) else (
    set "CMAKE_GENERATOR=Ninja"
    set "CMAKE_MAKE_PROGRAM=%NINJA_EXE%"
)

if not defined NDK_PATH (
    echo ERROR: NDK not found. Set ANDROID_NDK, ANDROID_SDK_ROOT, ANDROID_HOME, or pass --ndk-path
    exit /b 1
)

if not exist "%NDK_PATH%\build\cmake\android.toolchain.cmake" (
    echo ERROR: NDK toolchain not found at %NDK_PATH%
    echo Looked for: %NDK_PATH%\build\cmake\android.toolchain.cmake
    exit /b 1
)

echo Prerequisites OK.
echo   CMake: Found
echo   NDK: %NDK_PATH%
echo   Ninja: %NINJA_EXE%
echo   ABI: %ABI%
echo   Generator: %CMAKE_GENERATOR%
echo.

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
if defined CMAKE_MAKE_PROGRAM (
    cmake .. ^
      -G "%CMAKE_GENERATOR%" ^
      -DCMAKE_MAKE_PROGRAM="%CMAKE_MAKE_PROGRAM%" ^
      -DCMAKE_TOOLCHAIN_FILE="%NDK_PATH%\build\cmake\android.toolchain.cmake" ^
      -DANDROID_ABI=%ABI% ^
      -DANDROID_PLATFORM=%ANDROID_PLATFORM% ^
      -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
      -DBUILD_SHARED_LIBS=ON ^
      -DOQS_USE_OPENSSL=OFF ^
      -DOQS_BUILD_ONLY_LIB=ON
) else (
    cmake .. ^
      -G "%CMAKE_GENERATOR%" ^
      -DCMAKE_TOOLCHAIN_FILE="%NDK_PATH%\build\cmake\android.toolchain.cmake" ^
      -DANDROID_ABI=%ABI% ^
      -DANDROID_PLATFORM=%ANDROID_PLATFORM% ^
      -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
      -DBUILD_SHARED_LIBS=ON ^
      -DOQS_USE_OPENSSL=OFF ^
      -DOQS_BUILD_ONLY_LIB=ON
)

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
echo    mkdir android\app\src\main\jniLibs\%ABI%
echo    copy "%OUTPUT_SO%" android\app\src\main\jniLibs\%ABI%\liboqs.so
echo.
echo 2. Copy oqs headers:
echo    mkdir android\app\src\main\cpp\oqs_include
echo    xcopy /E /I liboqs\include\oqs android\app\src\main\cpp\oqs_include\oqs
echo.
echo 3. Build the Flutter app:
echo    cd android
echo    gradlew assembleDebug
echo.

endlocal
