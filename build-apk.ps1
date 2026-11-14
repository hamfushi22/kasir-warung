# Build APK Kasir Warung - PowerShell
$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectDir
Write-Host "==============================================="
Write-Host " Build APK Kasir Warung"
Write-Host "==============================================="
Write-Host ""

# 1. Cari Flutter
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    $candidates = @("C:\flutter\bin\flutter.bat", "C:\src\flutter\bin\flutter.bat", "D:\flutter\bin\flutter.bat", "$env:USERPROFILE\flutter\bin\flutter.bat")
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $flutterBin = Split-Path -Parent $c
            $env:Path = "$flutterBin;$env:Path"
            Write-Host "[OK] Flutter ketemu di $flutterBin"
            $flutter = Get-Command flutter -ErrorAction SilentlyContinue
            break
        }
    }
}
if (-not $flutter) {
    Write-Host "[INFO] Flutter belum terinstall. Mengunduh Flutter 3.47.9 sekitar 1 GB..."
    Write-Host "       Mohon tunggu, jangan tutup jendela ini."
    $zipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.9-stable.zip"
    $zipPath = Join-Path $env:TEMP "flutter_windows_3.47.9-stable.zip"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    Write-Host "[INFO] Mengekstrak Flutter ke C:\flutter ..."
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
    $env:Path = "C:\flutter\bin;$env:Path"
    Write-Host "[OK] Flutter terinstall di C:\flutter"
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
}
if ($flutter) {
    Write-Host ""
    Write-Host "[INFO] Versi Flutter:"
    flutter --version
} else {
    Write-Host "[GAGAL] Flutter tidak ketemu."
    Read-Host "Tekan Enter untuk keluar"
    exit 1
}

# 2. Cari Android SDK
$sdk = $null
if ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe")) { $sdk = $env:ANDROID_HOME }
if (-not $sdk -and (Test-Path "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe")) { $sdk = "$env:LOCALAPPDATA\Android\Sdk" }
if (-not $sdk -and (Test-Path "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe")) { $sdk = "$env:USERPROFILE\AppData\Local\Android\Sdk" }
if (-not $sdk -and (Test-Path "C:\Android\Sdk\platform-tools\adb.exe")) { $sdk = "C:\Android\Sdk" }
if (-not $sdk -and (Test-Path "D:\Android\Sdk\platform-tools\adb.exe")) { $sdk = "D:\Android\Sdk" }
if ($sdk) {
    Write-Host "[OK] Android SDK ketemu: $sdk"
    $env:ANDROID_HOME = $sdk
    $env:ANDROID_SDK_ROOT = $sdk
} else {
    Write-Host "[PERINGATAN] Android SDK tidak ketemu di lokasi umum."
}

# 2b. Java 17
Write-Host ""
Write-Host "[INFO] Mencari Java 17, dibutuhkan Android Gradle Plugin 8.3.0..."
$javaHome = $null
$jbr = "C:\Program Files\Android\Android Studio\jbr"
$jre = "C:\Program Files\Android\Android Studio\jre"
if (Test-Path "$jbr\bin\java.exe") { $javaHome = $jbr; Write-Host "[OK] Java 17 ketemu, Android Studio JBR: $javaHome" }
elseif (Test-Path "$jre\bin\java.exe") { $javaHome = $jre; Write-Host "[OK] Java ketemu, Android Studio JRE: $javaHome" }
else {
    $jdk17 = Get-ChildItem "C:\Program Files\Microsoft\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $jdk17) { $jdk17 = Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $jdk17) { $jdk17 = Get-ChildItem "C:\Program Files\Java\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($jdk17 -and (Test-Path "$($jdk17.FullName)\bin\java.exe")) {
        $javaHome = $jdk17.FullName
        Write-Host "[OK] Java 17 ketemu: $javaHome"
    }
}
if (-not $javaHome) {
    Write-Host "[INFO] JDK 17 belum ketemu. Mengunduh Microsoft OpenJDK 17..."
    $msiUrl = "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.msi"
    $msiPath = Join-Path $env:TEMP "microsoft-jdk-17.msi"
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
    Write-Host "[INFO] Menginstall JDK 17, mohon tunggu..."
    Start-Process msiexec -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait
    $jdk17 = Get-ChildItem "C:\Program Files\Microsoft\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jdk17 -and (Test-Path "$($jdk17.FullName)\bin\java.exe")) {
        $javaHome = $jdk17.FullName
        Write-Host "[OK] JDK 17 terinstall: $javaHome"
    } else {
        Write-Host "[GAGAL] JDK 17 tidak ketemu setelah install."
        Read-Host "Tekan Enter untuk keluar"
        exit 1
    }
}
$env:JAVA_HOME = $javaHome
Write-Host "[INFO] Versi Java yang dipakai:"
& "$javaHome\bin\java.exe" -version

# 3. Build
Write-Host ""
Write-Host "[INFO] Mengambil dependencies, flutter pub get..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[GAGAL] flutter pub get gagal. Periksa koneksi internet."
    Read-Host "Tekan Enter untuk keluar"
    exit 1
}
Write-Host ""
Write-Host "[INFO] Membangun APK release, beberapa menit, mohon tunggu..."
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[GAGAL] Build APK gagal. Lihat pesan error di atas."
    Read-Host "Tekan Enter untuk keluar"
    exit 1
}
Write-Host ""
Write-Host "==============================================="
Write-Host " BERHASIL! APK sudah jadi."
Write-Host "==============================================="
$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    $full = (Resolve-Path $apk).Path
    Write-Host "Lokasi APK: $full"
    Copy-Item $apk -Destination "$env:USERPROFILE\Desktop\KasirWarung.apk" -Force
    Write-Host "APK juga disalin ke Desktop sebagai KasirWarung.apk"
    Get-Item $apk | Format-Table Name, Length, LastWriteTime -AutoSize | Out-String | Write-Host
} else {
    Write-Host "APK tidak ketemu di $apk. Cek folder build\app\outputs\flutter-apk\"
}
Write-Host ""
Write-Host "PIN demo, GANTI setelah install:"
Write-Host "  Owner : 1234"
Write-Host "  Kasir : 1111"
Write-Host ""
Read-Host "Tekan Enter untuk keluar"
