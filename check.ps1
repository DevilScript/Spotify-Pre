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
}

# ฟังก์ชันสำหรับการบันทึกข้อมูลลงในไฟล์ log
function Write-Log {
    param (
        [string]$message
    )
    
    $logDirPath = "$env:APPDATA\Motify"  # Path ของโฟลเดอร์ Motify
    $logFilePath = "$logDirPath\log.txt"
    
    if (-not (Test-Path -Path $logDirPath)) {
        New-Item -ItemType Directory -Path $logDirPath -Force | Out-Null
    }

    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
    Add-Content -Path $logFilePath -Value $logMessage
}

# ฟังก์ชันสำหรับลบโปรแกรมจาก registry
function Remove-StartupRegistry {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"

    Remove-ItemProperty -Path $regKey -Name $regValueName -ErrorAction SilentlyContinue
    Write-Log "SystemID.exe removed from startup registry."
}

# ฟังก์ชันสำหรับตรวจสอบ HWID และคีย์
function Check-HwidAndKey {
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$appDataPath\Motify\key_hwid.json"

    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Log "Error: Failed to retrieve HWID."
        exit
    }

    if (Test-Path $filePath) {
        $data = Get-Content $filePath | ConvertFrom-Json
        if (-not $data.key -or -not $data.hwid) {
            $exePath = "$env:APPDATA\Motify\SystemID.exe"
            Write-Log "Error: Key or HWID missing in the file. Removing related files."
            Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
            Remove-StartupRegistry
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }

        $key = $data.key
        $hwidFromFile = $data.hwid
        $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
        $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

        $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }
        if ($response.Count -eq 0 -or $response[0].used -eq $false -or $response[0].hwid -ne $hwidFromFile) {
            $exePath = "$env:APPDATA\Motify\SystemID.exe"
            Write-Log "Error: Invalid or deleted key. Removing related files."
            Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
            Remove-StartupRegistry
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }
    } else {
        $exePath = "$env:APPDATA\Motify\SystemID.exe"
        Write-Log "Error: No key_hwid.json file found. Removing related files."
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
        Remove-StartupRegistry
        exit
    }
}

# เรียกใช้งานฟังก์ชัน
Check-HwidAndKey
