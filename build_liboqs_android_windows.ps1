# Build liboqs for Android ARM64-v8a on Windows using PowerShell
# Usage: .\build_liboqs_android_windows.ps1
# Prerequisites: CMake, Git, Android NDK installed and on PATH

param(
    [string]$NDKPath = "C:\Users\exter\AppData\Local\Android\sdk\ndk\27.0.12077973",
    [string]$ABI = "arm64-v8a",
    [string]$AndroidPlatform = "android-21",
    [string]$BuildType = "Release",
    [string]$BuildGenerator = "Ninja"
)

$ErrorActionPreference = "Stop"

Write-Host "===== liboqs Android Build Script (PowerShell) =====" -ForegroundColor Cyan
Write-Host "NDK Path: $NDKPath"
Write-Host "ABI: $ABI"
Write-Host "Platform: $AndroidPlatform"
Write-Host "Build Type: $BuildType"
Write-Host "Generator: $BuildGenerator"
Write-Host ""

# Verify prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
$cmakeExe = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmakeExe) {
    Write-Host "ERROR: CMake not found on PATH. Install CMake and add to PATH." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ CMake found: $($cmakeExe.Source)" -ForegroundColor Green

$gitExe = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExe) {
    Write-Host "ERROR: Git not found on PATH. Install Git for Windows." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Git found: $($gitExe.Source)" -ForegroundColor Green

if (-not (Test-Path $NDKPath)) {
    Write-Host "ERROR: NDK not found at $NDKPath" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ NDK found: $NDKPath" -ForegroundColor Green

# Check for Ninja
$ninjaExe = Get-Command ninja -ErrorAction SilentlyContinue
if (-not $ninjaExe) {
    Write-Host "  ⚠ Ninja not found. Using 'Unix Makefiles' generator (slower)." -ForegroundColor Yellow
    $BuildGenerator = "Unix Makefiles"
} else {
    Write-Host "  ✓ Ninja found: $($ninjaExe.Source)" -ForegroundColor Green
}

Write-Host ""

# Clone or verify liboqs
$liboqsDir = "liboqs"
if (-not (Test-Path $liboqsDir)) {
    Write-Host "Cloning liboqs repository..." -ForegroundColor Yellow
    & git clone --depth 1 https://github.com/open-quantum-safe/liboqs.git $liboqsDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to clone liboqs" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "liboqs directory already exists. Skipping clone." -ForegroundColor Yellow
}

Push-Location $liboqsDir

# Create and configure build directory
$buildDir = "build_android_$ABI"
if (Test-Path $buildDir) {
    Write-Host "Removing old build directory..." -ForegroundColor Yellow
    Remove-Item $buildDir -Recurse -Force
}

Write-Host "Creating build directory: $buildDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
Push-Location $buildDir

# Configure with CMake
Write-Host "Running CMake configuration..." -ForegroundColor Yellow
$toolchainFile = "$NDKPath\build\cmake\android.toolchain.cmake"

& cmake ".." `
    -G $BuildGenerator `
    -DCMAKE_TOOLCHAIN_FILE="$toolchainFile" `
    -DANDROID_ABI=$ABI `
    -DANDROID_PLATFORM=$AndroidPlatform `
    -DCMAKE_BUILD_TYPE=$BuildType `
    -DBUILD_SHARED_LIBS=ON

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: CMake configuration failed" -ForegroundColor Red
    exit 1
}

# Build
Write-Host "Building liboqs (this may take 2-10 minutes)..." -ForegroundColor Yellow
& cmake --build . --config $BuildType

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Build successful!" -ForegroundColor Green

# Find output
$outputSo = Get-ChildItem -Path "." -Filter "liboqs.so" -Recurse | Select-Object -First 1
if (-not $outputSo) {
    Write-Host "ERROR: liboqs.so not found in build directory" -ForegroundColor Red
    exit 1
}

$outputPath = $outputSo.FullName
Write-Host ""
Write-Host "===== BUILD COMPLETE =====" -ForegroundColor Cyan
Write-Host "Output: $outputPath" -ForegroundColor Green
Write-Host ""

Pop-Location  # back to liboqs/
Pop-Location  # back to original directory

# Guide user on next steps
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Create jniLibs directory if it doesn't exist:"
Write-Host "   New-Item -ItemType Directory -Path 'android\app\src\main\jniLibs\$ABI' -Force" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Copy liboqs.so to your Android project:"
Write-Host "   Copy-Item '$outputPath' -Destination 'android\app\src\main\jniLibs\$ABI\liboqs.so'" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Copy oqs headers:"
Write-Host "   New-Item -ItemType Directory -Path 'android\app\src\main\cpp\oqs_include' -Force" -ForegroundColor Cyan
Write-Host "   Copy-Item 'liboqs\liboqs\include\oqs\*' -Destination 'android\app\src\main\cpp\oqs_include\' -Recurse" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Build the Flutter app:"
Write-Host "   cd android" -ForegroundColor Cyan
Write-Host "   gradlew assembleDebug" -ForegroundColor Cyan
Write-Host ""
