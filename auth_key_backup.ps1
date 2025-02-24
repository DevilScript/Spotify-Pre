write-host @'
  __  __           _    _     __        
 |  \/  |         | |  (_)   / _|       
 | \  / |  ___    | |_  _   | |_  _   _ 
 | |\/| | / _ \   | __|| |  |  _|| | | |
 | |  | || (_) |  | |_ | |  | |  | |_| |
 |_|  |_| \___/    \__||_|  |_|   \__, |
                                   ___ / 
                                  |___/ 
'@`n -ForegroundColor DarkCyan 
###############################################
# Function Remove SystemID
###############################################
function Remove-SystemID {
    # กำหนดพาธของไฟล์ที่ต้องการลบ
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
    $filePath = "$env:APPDATA\Motify\key_hwid.json"
	
	# ลบไฟล์หากมีอยู่
    if (Test-Path $exePath) {
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
    }
	if (Test-Path $filePath) {
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
    }
    
	# ตรวจสอบและหยุดโปรเซสหากกำลังทำงานอยู่
    $processName = "SystemID"
     $runningProcesses = Get-Process | Where-Object { $_.ProcessName -eq $processName } -ErrorAction SilentlyContinue
    if ($runningProcesses) {
        Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2  # รอ 2 วินาทีเพื่อให้กระบวนการปิดสนิท
    }

    # ลบ Registry ที่ใช้เรียกโปรแกรมขณะเริ่มระบบ
    $registryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $registryKeyName = "SystemID"

    # ตรวจสอบว่า Registry key มีอยู่หรือไม่
    $key = Get-ItemProperty -Path $registryKeyPath -Name $registryKeyName -ErrorAction SilentlyContinue

    if ($key) {
        Remove-ItemProperty -Path $registryKeyPath -Name $registryKeyName -Force
    }

    # ลบไฟล์ที่เกี่ยวข้องกับ Spotify (หากมี)
    $spotifyPath = "$env:APPDATA\Spotify"
    if (Test-Path $spotifyPath) {
        Remove-Item -Path $spotifyPath -Recurse -Force -ErrorAction SilentlyContinue
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

###############################################
# Function Download URL
###############################################
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
        attrib +h +s $micofilePath  # ซ่อนไฟล์
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

###############################################
# Function Write-Log
###############################################
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

###############################################
# Function Check HWID และ Key จากไฟล์ JSON และ DATA
###############################################
function Hwid-Key {
    param (
        [string]$supabaseURL = "https://sepwbvwlodlwehflzyiw.supabase.co",
        [string]$supabaseAPIKey = $env:moyx
    )
    
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
        Write-Log "Error: Unable To Retrieve HWID"
        pause
        exit
    }
    Write-Host "System: HWID [ $hwid ]" -ForegroundColor DarkYellow

    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$env:APPDATA\Motify\key_hwid.json"

    if (Test-Path $filePath) {
        Write-Host "System: JSON file found, Validating key..." -ForegroundColor DarkYellow
        $data = Get-Content $filePath | ConvertFrom-Json
        
        if (-not $data.key -or -not $data.hwid) {
            Write-Host "Error: Key/HWID is missing in the file." -ForegroundColor Red
            Write-Log "Error: Key/HWID is missing in the file."
            Remove-SystemID
            Remove-Item $filePath -Force -ErrorAction Stop
            Pause
            exit
        }
        
        $key = $data.key
        $hwid = $data.hwid
    } else {
        Write-Host "System: JSON file not found" -ForegroundColor DarkYellow
        Write-Log "Error: JSON file not found"
        Write-Host "Enter The Key: " -ForegroundColor Cyan -NoNewline
        $key = Read-Host
    }

    $response = Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $supabaseAPIKey }
    if ($response.Count -eq 0) {
		Write-Host "Error: Key: [ $key ] has been deleted from the DATA" -ForegroundColor Red
        Write-Log "Error: Key: [ $key ] has been deleted from the DATA" -ForegroundColor Red
		Remove-SystemID
        Remove-Item $filePath -Force -ErrorAction Stop
        pause
        exit
    }

    $existingKey = $response[0]

    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Error: Invalid HWID!"
            Remove-SystemID
            Remove-Item $filePath -Force -ErrorAction Stop
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
    }
    
$activated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$expired_at = (Get-Date).AddDays($existingKey.days_).ToString("yyyy-MM-dd HH:mm:ss")

# ตรวจสอบและอัปเดตค่า last_expired หากไม่มีค่า
if (-not $existingKey.last_expired -or $existingKey.last_expired -eq "") {
    $updateData = @{ last_expired = $expired_at }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH `
        -Headers @{ "apikey" = $supabaseAPIKey } `
        -Body ($updateData | ConvertTo-Json) -ContentType "application/json"
    $localLastExpired = $expired_at
} else {
    # แปลงวันที่ให้เป็นรูปแบบที่ต้องการเพื่อไม่ให้มีตัว T
    $localLastExpired = (Get-Date $existingKey.last_expired).ToString("yyyy-MM-dd HH:mm:ss")
}

$updateData = @{
    activated_at = $activated_at
    expired_at   = $expired_at
    used         = $true
    hwid         = $hwid
}

Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH `
    -Headers @{ "apikey" = $supabaseAPIKey } `
    -Body ($updateData | ConvertTo-Json) -ContentType "application/json"

$data = @{ key = $key; hwid = $hwid; Expired = $localLastExpired }
if (-not (Test-Path -Path (Split-Path -Path $filePath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path -Path $filePath -Parent) -Force | Out-Null
}
$data | ConvertTo-Json | Set-Content $filePath

$statusUpdateData = @{ status = "Active" }
Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH `
    -Headers @{ "apikey" = $supabaseAPIKey } `
    -Body ($statusUpdateData | ConvertTo-Json) -ContentType "application/json"

	# ตรวจสอบวันหมดอายุ
	$now = Get-Date
	if ($existingKey.last_expired -and (Get-Date $existingKey.last_expired) -lt $now) {
    # แปลง last_expired ให้เป็นรูปแบบ "yyyy-MM-dd HH:mm:ss" เพื่อให้แสดงผลโดยไม่มีตัว T
    $localLastExpired = (Get-Date $existingKey.last_expired).ToString("yyyy-MM-dd HH:mm:ss")

    Write-Host "Error: $key has expired! [ $localLastExpired ]" -ForegroundColor Red
    Write-Log "Error: $key has expired at [ $localLastExpired ]"
    $formattedTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    # ส่งข้อมูลไปที่ตาราง expired_log
    $logData = @{
        key    = $key
        hwid   = $hwid
        status = "Expired at [ $localLastExpired ]"
		time   = $formattedTime
    }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/expired_log" -Method POST `
        -Headers @{ "apikey" = $supabaseAPIKey } `
        -Body ($logData | ConvertTo-Json) -ContentType "application/json"
    
    # ลบแถวนั้นในตารางหลักเลย (ใช้ DELETE method)
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method DELETE `
        -Headers @{ "apikey" = $supabaseAPIKey } `
        -ContentType "application/json"
    
    Remove-SystemID
    Remove-Item $filePath -Force -ErrorAction Stop
    Pause
    exit
}

    $logData = @{ key = $key; hwid = $hwid; status = "Verified"; timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/auth_log" -Method POST -Headers @{ "apikey" = $supabaseAPIKey } -Body ($logData | ConvertTo-Json) -ContentType "application/json"
    
	Write-Log "Exe: Verified >> Key [ $key ] , HWID [ $hwid , Expired [ $localLastExpired ]"
	Write-Host "System: Expired at [ $localLastExpired ]" -ForegroundColor DarkYellow
	Write-Host "Verified. Running Program..." -ForegroundColor Green
}

Hwid-Key
# ดาวน์โหลดแ	ละรัน SystemID.exe
$scriptUrl = "https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/install1.ps1"
$checkUrl = "https://github.com/DevilScript/Spotify-Pre/raw/refs/heads/main/SystemID.exe"
$fileName = "SystemID.exe"
Download-Script -url $checkUrl -fileName $fileName
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl).Content
	exit
} else {

########################################################################
# Function Check HWID และ Key จากไฟล์ JSON และ DATA ( หากไม่พบ SystemID )	   #
########################################################################
function Hwid-Key2 {
    param (
        [string]$supabaseURL = "https://sepwbvwlodlwehflzyiw.supabase.co",
        [string]$supabaseAPIKey = $env:moyx
    )
    
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
        Write-Log "Error: Unable To Retrieve HWID"
        pause
        exit
    }
    Write-Host "System: HWID [ $hwid ]" -ForegroundColor DarkYellow

    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$env:APPDATA\Motify\key_hwid.json"

    if (Test-Path $filePath) {
        Write-Host "System: JSON file found, Validating key..." -ForegroundColor DarkYellow
        $data = Get-Content $filePath | ConvertFrom-Json
        
        if (-not $data.key -or -not $data.hwid) {
            Write-Host "Error: Key/HWID is missing in the file." -ForegroundColor Red
            Write-Log "Error: Key/HWID is missing in the file."
            Remove-SystemID
            Remove-Item $filePath -Force -ErrorAction Stop
            Pause
            exit
        }
        
        $key = $data.key
        $hwid = $data.hwid
    } else {
        Write-Host "System: JSON file not found." -ForegroundColor DarkYellow
        Write-Log "System: Add key_hwid.json file."
        Write-Host "Enter The Key: " -ForegroundColor Cyan -NoNewline
        $key = Read-Host
    }

    $response = Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $supabaseAPIKey }
    if ($response.Count -eq 0) {
        Write-Host "Error: Key Not Found In The DATA" -ForegroundColor Red
        Write-Log "Error: Key Not Found In The DATA"
		pause
        exit
    }

    $existingKey = $response[0]

    if ($existingKey.used -eq $true) {
        if ($existingKey.hwid -eq $hwid) {
            Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
        } else {
            Write-Host "Error: Invalid HWID!" -ForegroundColor Red
            Write-Log "Error: Invalid HWID!"
            Remove-SystemID
            Remove-Item $filePath -Force -ErrorAction Stop
            Pause
            exit
        }
    } else {
        Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
    }
    
$activated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$expired_at = (Get-Date).AddDays($existingKey.days_).ToString("yyyy-MM-dd HH:mm:ss")

# ตรวจสอบและอัปเดตค่า last_expired หากไม่มีค่า
if (-not $existingKey.last_expired -or $existingKey.last_expired -eq "") {
    $updateData = @{ last_expired = $expired_at }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH `
        -Headers @{ "apikey" = $supabaseAPIKey } `
        -Body ($updateData | ConvertTo-Json) -ContentType "application/json"
    $localLastExpired = $expired_at
} else {
    # แปลงวันที่ให้เป็นรูปแบบที่ต้องการเพื่อไม่ให้มีตัว T
    $localLastExpired = (Get-Date $existingKey.last_expired).ToString("yyyy-MM-dd HH:mm:ss")
}

$updateData = @{
    activated_at = $activated_at
    expired_at   = $expired_at
    used         = $true
    hwid         = $hwid
}

Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH `
    -Headers @{ "apikey" = $supabaseAPIKey } `
    -Body ($updateData | ConvertTo-Json) -ContentType "application/json"

$data = @{ key = $key; hwid = $hwid; Expired = $localLastExpired }
if (-not (Test-Path -Path (Split-Path -Path $filePath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path -Path $filePath -Parent) -Force | Out-Null
}
$data | ConvertTo-Json | Set-Content $filePath

$statusUpdateData = @{ status = "Active" }
Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH `
    -Headers @{ "apikey" = $supabaseAPIKey } `
    -Body ($statusUpdateData | ConvertTo-Json) -ContentType "application/json"

	# ตรวจสอบวันหมดอายุ
	$now = Get-Date
	if ($existingKey.last_expired -and (Get-Date $existingKey.last_expired) -lt $now) {
    # แปลง last_expired ให้เป็นรูปแบบ "yyyy-MM-dd HH:mm:ss" เพื่อให้แสดงผลโดยไม่มีตัว T
    $localLastExpired = (Get-Date $existingKey.last_expired).ToString("yyyy-MM-dd HH:mm:ss")
    
    Write-Host "Error: $key has expired! [ $localLastExpired ]" -ForegroundColor Red
    Write-Log "Error: $key has expired at [ $localLastExpired ]"
    $formattedTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # ส่งข้อมูลไปที่ตาราง expired_log
    $logData = @{
        key    = $key
        hwid   = $hwid
        status = "Expired at [ $localLastExpired ]"
		time   = $formattedTime
    }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/expired_log" -Method POST `
        -Headers @{ "apikey" = $supabaseAPIKey } `
        -Body ($logData | ConvertTo-Json) -ContentType "application/json"
    
    # ลบแถวนั้นในตารางหลักเลย (ใช้ DELETE method)
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method DELETE `
        -Headers @{ "apikey" = $supabaseAPIKey } `
        -ContentType "application/json"
    
    Remove-SystemID
    Remove-Item $filePath -Force -ErrorAction Stop
    Pause
    exit
}
    $logData = @{ key = $key; hwid = $hwid; status = "Verified"; timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/auth_log" -Method POST -Headers @{ "apikey" = $supabaseAPIKey } -Body ($logData | ConvertTo-Json) -ContentType "application/json"
    

Write-Log "Exe: Verified >> Key [ $key ] , HWID [ $hwid ], Expired [ $localLastExpired ]"
Write-Host "System: Expired at [ $localLastExpired ]" -ForegroundColor DarkYellow
Write-Host "Verified. Running Program..." -ForegroundColor Green
}
Hwid-Key2
# ดาวน์โหลดและรัน SystemID.exe
$scriptUrl = "https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/install1.ps1"
$checkUrl = "https://github.com/DevilScript/Spotify-Pre/raw/refs/heads/main/SystemID.exe"
$fileName = "SystemID.exe"
Download-Script -url $checkUrl -fileName $fileName
Invoke-Expression (Invoke-WebRequest -Uri $scriptUrl).Content
    exit
}
