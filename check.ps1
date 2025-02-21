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

function Remove-Spotify {
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
	$exeMPath = "$env:APPDATA\Microsoft\SystemID.exe"
    if (Test-Path $exePath) {
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
        Write-Log "System: ID removed from folder."
    }

    # ลบ Registry entry สำหรับ Startup
    $registryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $registryKeyName = "SystemID"

    # ตรวจสอบว่า Registry key มีอยู่หรือไม่
    $key = Get-ItemProperty -Path $registryKeyPath -Name $registryKeyName -ErrorAction SilentlyContinue

    if ($key) {
        Remove-ItemProperty -Path $registryKeyPath -Name $registryKeyName -Force
        Write-Log "System: ID removed."
    } else {
        Write-Log "System: ID not found."
    }

    # ลบไฟล์ Spotify (ในกรณีที่มีการติดตั้ง)
    $spotifyPath = "$env:APPDATA\Spotify"
    if (Test-Path $spotifyPath) {
        Remove-Item -Path $spotifyPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "System: removed from Data."
		Write-Log "___________________________"
    } else {
        Write-Log "System: not found in Data."
		Write-Log "___________________________"
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

# ฟังก์ชันเพิ่มโปรแกรมใน Registry สำหรับเริ่มต้นระบบ
function Add-StartupRegistry {
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
	$exeMPath = "$env:APPDATA\Motify\SystemID.exe"

    # ตรวจสอบว่าไฟล์ .exe มีอยู่หรือไม่
    if (-not (Test-Path $exePath)) {
        Write-Log "Error: $exePath not found for up."
        exit
    }

    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"
	$regValueName2 = "Microsofted"

    # เพิ่มคีย์ใน Registry
    Set-ItemProperty -Path $regKey -Name $regValueName -Value $exePath
	Set-ItemProperty -Path $regKey -Name $regValueName2 -Value $exeMPath
    Write-Log "System: ID added"
    Write-Log "___________________________"
}

# ฟังก์ชันตรวจสอบ HWID และ Key
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
            Write-Log "Error: Key or HWID missing in the file."
			Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }

        $key = $data.key
        $hwidFromFile = $data.hwid
        
        # Supabase URL และ API Key ที่ต้องการใช้
        $url = "https://sepwbvwlodlwehflzyiw.supabase.co/rest/v1/keys?key=eq.$key"
        $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

        # เชื่อมต่อกับ API และตรวจสอบ Key และ HWID
        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "apikey" = $key_api }

            # ตรวจสอบผลลัพธ์จาก API
            if ($response.Count -eq 0 -or $response[0].used -eq $false -or $response[0].hwid -ne $hwidFromFile) {
                Write-Log "Error: Invalide key. Removing files."
            Remove-Item $filePath -Force
            Remove-Spotify
                exit
            } else {
                Write-Log "Success: Key and HWID match."
                Add-StartupRegistry  # ✅ ถ้า Key และ HWID ถูกต้อง ให้เพิ่ม Registry
            }
        }
        catch {
            Write-Log "Error: Failed to connect to API."
			Write-Log "___________________________"
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }
    } else {
        Write-Log "Error: No key_hwid.json file found."
            Remove-Item $filePath -Force
            Remove-Spotify
        exit
    }
}
# เรียกใช้งานฟังก์ชัน
Check-HwidAndKey
