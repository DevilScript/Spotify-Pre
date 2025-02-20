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

# ฟังก์ชันสำหรับการเพิ่มโปรแกรมใน registry สำหรับการเริ่มต้นระบบ
function Add-StartupRegistry {
    $exePath = "$env:APPDATA\Motify\SystemID.exe"

    # ตรวจสอบว่าไฟล์ .exe มีอยู่หรือไม่
    if (-not (Test-Path $exePath)) {
        Write-Host "Error: $exePath not found." -ForegroundColor Red
        Write-Log "Error: $exePath not found for startup."
        exit
    }

    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"

    # เพิ่มคีย์ใน Registry
    Set-ItemProperty -Path $regKey -Name $regValueName -Value $exePath

    Write-Host "SystemID.exe has been added to startup registry." -ForegroundColor Green
    Write-Log "SystemID.exe added to startup registry."
}

# ฟังก์ชันสำหรับการลบโปรแกรมจาก registry
function Remove-StartupRegistry {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"

    # ลบคีย์ใน Registry
    Remove-ItemProperty -Path $regKey -Name $regValueName -ErrorAction SilentlyContinue

    Write-Host "SystemID.exe has been removed from startup registry." -ForegroundColor Red
    Write-Log "SystemID.exe removed from startup registry."
}

# ฟังก์ชันสำหรับตรวจสอบ HWID และคีย์
function Check-HwidAndKey {
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$appDataPath\Motify\key_hwid.json"

    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Host "Error: Unable To Retrieve HWID" -ForegroundColor Red
        Write-Log "Error: Failed to retrieve HWID."
        exit
    }

    Write-Host "System: HWID [ $hwid ]" -ForegroundColor DarkYellow

    if (Test-Path $filePath) {
        Write-Log "Success: Found key_hwid.json file."
        $data = Get-Content $filePath | ConvertFrom-Json

        if (-not $data.key -or -not $data.hwid) {
            Write-Host "Error: key or hwid is missing in the file." -ForegroundColor Red
            Write-Log "Error: key or hwid is missing in the file."
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }

        $key = $data.key
        $hwidFromFile = $data.hwid

        $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
        $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI" 

        $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }

        if ($response.Count -eq 0) {
            Write-Host "Error: Key Deleted From Server." -ForegroundColor Red
            Write-Log "Error: Key deleted from server. Removing key_hwid.json file."
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }

        $existingKey = $response[0]

        if ($existingKey.used -eq $true) {
            if ($existingKey.hwid -eq $hwidFromFile) {
                Write-Host "System: Key Matches Your HWID." -ForegroundColor DarkYellow
                Write-Log "Success: Key matches HWID."
                # เพิ่ม registry เมื่อ HWID และคีย์ตรงกัน
                Add-StartupRegistry
            } else {
                Write-Host "Error: Invalid HWID!" -ForegroundColor Red
                Write-Log "Error: Invalid HWID for the key."
                Remove-Item $filePath -Force
                Remove-Spotify
                # ลบ registry เมื่อ HWID และคีย์ไม่ตรงกัน
                Remove-StartupRegistry
                exit
            }
        } else {
            Write-Host "System: Linking to HWID..." -ForegroundColor DarkYellow
            Write-Log "Success: Linking key to HWID."
        }
    } else {
        Write-Host "Error: No key_hwid.json file found." -ForegroundColor Red
        Write-Log "Error: No key_hwid.json file found."
        exit
    }
}

# เรียกใช้งานฟังก์ชัน
Check-HwidAndKey
