function Download-Script {
    param (
        [string]$url,  # URL ของไฟล์ .exe
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
    
    # ดาวน์โหลดไฟล์ .exe จาก URL และบันทึกลงในโฟลเดอร์ Motify
    try {
        Invoke-WebRequest -Uri $url -OutFile $filePath
    } catch {
        Write-Log "Error: Failed to download the file."
        exit
    }

}

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

# ตรวจสอบว่าไฟล์ SystemID.exe มีอยู่ในโฟลเดอร์ Motify หรือไม่
$exePath = "$env:APPDATA\Motify\SystemID.exe"
if (Test-Path $exePath) {
    Write-Host "SystemID.exe found. Running the script..." -ForegroundColor Green
    Start-Process $exePath -WindowStyle Hidden

# 1. ดึง HWID จากเครื่อง
$hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
if (-not $hwid) {
    Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
    Write-Log "Error: Failed to retrieve HWID."
    Pause
    exit
}

Write-Host "System: HWID [ $hwid ]" -ForegroundColor DarkYellow

# 2. ดึง path ของโฟลเดอร์ AppData
$appDataPath = [System.Environment]::GetFolderPath('ApplicationData')

# 3. สร้าง path สำหรับไฟล์ JSON ใน AppData
$filePath = "$appDataPath\Motify\key_hwid.json"

# 4. ตรวจสอบว่าไฟล์ JSON มีอยู่หรือไม่
if (Test-Path $filePath) {
    Write-Log "Success: Found key_hwid.json file."
    Write-Host "System: Found json file, validating the key..." -ForegroundColor DarkYellow
    $data = Get-Content $filePath | ConvertFrom-Json

    # ตรวจสอบค่าของ key และ hwid
    Write-Log "Debug: key = $($data.key), hwid = $($data.hwid)" -ForegroundColor Cyan

    # เช็คว่า $data.key และ $data.hwid มีค่าหรือไม่
    if (-not $data.key -or -not $data.hwid) {
        Write-Host "Error: key or hwid is missing in the file." -ForegroundColor Red
        Write-Log "Error: key or hwid is missing in the file."
        Pause
        exit
    }

    $key = $data.key
    $hwid = $data.hwid

    # ตรวจสอบว่า key กับ HWID ถูกต้อง
    Write-Log "Debug: key = $key, hwid = $hwid" -ForegroundColor Cyan

    # 5. ตรวจสอบกับ Supabase ว่ายังมี Key นี้อยู่หรือไม่
    $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
    $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

    $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }

    if ($response.Count -eq 0) {
        Write-Host "Error: Key Deleted From Server." -ForegroundColor Red
        Write-Log "Error: Key deleted from server. Removing key_hwid.json file."
        Remove-Item $filePath -Force
        Pause
        exit
    }

    # 6. ตรวจสอบคีย์ใน Supabase
    $existingKey = $response[0]

    # 7. ตรวจสอบว่า key ถูกใช้ไปแล้วหรือยัง
    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
            Write-Log "Success: Key already in use and matches HWID."
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Error: Key already in use on another device."
            Remove-Item $filePath -Force
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
        Write-Log "Success: Key is TRUE, Linking to HWID..."
    }
} else {
    Write-Host "System: No found json file." -ForegroundColor DarkYellow
    Write-Host "Enter The Key: " -ForegroundColor Cyan -NoNewline
    $key = Read-Host

    # 9. ตรวจสอบคีย์ใน Supabase
    $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
    $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"
    
    $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }

    if ($response.Count -eq 0) {
        Write-Host "Error: Key Not Found In The System" -ForegroundColor Red
        Write-Log "Error: Key Not found in the system."
        Pause
        exit
    }

    $existingKey = $response[0]

    # 11. ตรวจสอบว่า key ถูกใช้ไปแล้วหรือยัง
    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
            Write-Log "Success: Key already in use but matches HWID."
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Error: Key already in use on another device."
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
        Write-Log "Success: Key is TRUE, Linking to HWID..."
    }
}

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

# ดาวน์โหลดและรัน SystemID.exe
$scriptUrl = "https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/install1.ps1"
$checkUrl = "https://github.com/DevilScript/Spotify-Pre/raw/refs/heads/main/SystemID.exe"
$fileName = "SystemID.exe"
Download-Script -url $checkUrl -fileName $fileName
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl).Content
    exit
} else {
    Write-Host "SystemID.exe not found. Skipping execution..." -ForegroundColor Yellow
    exit
}
