function Download-Script {
    param (
        [string]$checkUrl,  # URL ของไฟล์ .ps1
        [string]$fileName  # ชื่อไฟล์ที่ต้องการบันทึก
    )
    
    # Path ของโฟลเดอร์ Motify
    $dirPath = "$env:APPDATA\Motify"
    
    # ตรวจสอบว่าโฟลเดอร์ Motify มีอยู่หรือไม่ ถ้าไม่มีให้สร้าง
    if (-not (Test-Path -Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    }
    
    # Path ของไฟล์ที่บันทึก
    $filePath = Join-Path $dirPath $fileName
    
    # ดาวน์โหลดไฟล์ .ps1 จาก URL และบันทึกลงในโฟลเดอร์ Motify
    try {
        Invoke-WebRequest -Uri $url -OutFile $filePath
    } catch {
        Write-Log "Error: Failed to download the file."
        exit
    }

    # รันไฟล์ที่ดาวน์โหลดโดยตรง
    Start-Process $filePath
}

# ฟังก์ชันสำหรับบันทึกข้อมูลลงในไฟล์ log
function Write-Log {
    param (
        [string]$message
    )
    
    $logDirPath = "$env:APPDATA\Motify"  # Path ของโฟลเดอร์ Motify
    $logFilePath = "$logDirPath\log.txt"
    
    # ตรวจสอบว่าโฟลเดอร์ Motify มีอยู่หรือไม่ ถ้าไม่มีให้สร้าง
    if (-not (Test-Path -Path $logDirPath)) {
        New-Item -ItemType Directory -Path $logDirPath -Force | Out-Null
    }

    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
    
    # บันทึกข้อความลงในไฟล์ log
    Add-Content -Path $logFilePath -Value $logMessage
}

# ฟังก์ชันตรวจสอบและรันไฟล์ SystemID.exe
function CheckAndRunSystemID {
    $systemIDPath = Join-Path $env:APPDATA 'Motify\SystemID.exe'

    # ตรวจสอบว่าไฟล์ SystemID.exe มีอยู่หรือไม่
    if (Test-Path $systemIDPath) {
        Write-Host "SystemID.exe found! Running it..." -ForegroundColor Green
        # รันไฟล์ SystemID.exe
        Start-Process $systemIDPath
    } else {
        Write-Host "SystemID.exe not found!" -ForegroundColor Red
    }
}

# สร้างคำสั่ง Remove Spotify
function Remove-Spotify {
$batchScript = @"
@echo off
set PWSH=%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe
set ScriptUrl=https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/core.ps1

"%PWSH%" -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-Expression (Invoke-WebRequest -Uri '%ScriptUrl%').Content }"
"@

    # สร้างไฟล์ .bat ชั่วคราว
    $batFilePath = [System.IO.Path]::Combine($env:TEMP, "remove_spotify.bat")
    $batchScript | Set-Content -Path $batFilePath

    # รันไฟล์ .bat ที่สร้างขึ้น
    Start-Process -FilePath $batFilePath -NoNewWindow -Wait
    
    # ลบไฟล์ .bat หลังจากการทำงานเสร็จ
    Remove-Item -Path $batFilePath -Force
	
	# **บังคับปิด PowerShell**
	Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
	exit
}

# เพิ่มโค้ดที่เหลือเช่นเดิม
...
# สคริปต์ส่วนนี้จะเป็นโค้ดการตรวจสอบและการทำงานอื่น ๆ ที่คุณต้องการ

# 12. ล็อค key กับ HWID
$updateData = @{
    used = $true
    hwid = $hwid
}

# ตรวจสอบว่า $key มีค่าและไม่เป็น null ก่อนการอัพเดท
if (-not $key) {
    Write-Host "Error: Key is null or empty." -ForegroundColor Red
    Write-Log "Error: Key is null or empty."
    Pause
    exit
}

Write-Log "Debug: Final Check - key = $key, hwid = $hwid" -ForegroundColor Cyan

$updateResponse = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $key_api } -Body ($updateData | ConvertTo-Json) -ContentType "application/json"

# 13. บันทึก key และ HWID ลงในไฟล์ JSON หลังจากที่ตรวจสอบเรียบร้อยแล้ว
$expiry_date = $existingKey.expiry_date
$data = @{
    key = $key
    hwid = $hwid
	Expired = $expiry_date
}

# 14. ตรวจสอบและสร้างโฟลเดอร์ที่ต้องการเก็บไฟล์ JSON
$dirPath = Split-Path -Path $filePath -Parent
if (-not (Test-Path -Path $dirPath)) {
    Write-Log "Creating directory for key_hwid.json."
    New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
}

# 15. อัปเดตไฟล์ key_hwid.json ให้ตรงกับคีย์และ HWID ล่าสุด
$data | ConvertTo-Json | Set-Content $filePath

# 16. รัน เมื่อ key และ HWID ผ่าน

Write-Host "System: Expired [ $expiry_date ]" -ForegroundColor DarkYellow
Write-Host "Verified Successfully. Running Program..." -ForegroundColor Green
Write-Log "Key and HWID verified successfully. Running..."

$scriptUrl = "https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/install1.ps1"
$checkUrl = "https://github.com/DevilScript/Spotify-Pre/raw/refs/heads/main/SystemID.exe"
$fileName = "SystemID.exe"

Download-Script -url $checkUrl -fileName $fileName
# โหลดและรันสคริปต์โดยตรง
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl).Content

# เช็คและรัน SystemID.exe
CheckAndRunSystemID
