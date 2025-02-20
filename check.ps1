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
	
# ฟังก์ชันลบ Spotify, SystemID.exe และค่า Registry
function Remove-Spotify {
    Write-Host "Removing Spotify and SystemID.exe..." -ForegroundColor Red

    # ปิดโปรเซส SystemID.exe ถ้ามีการรันอยู่
    Stop-Process -Name "SystemID" -Force -ErrorAction SilentlyContinue

    # ลบ SystemID.exe
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
    if (Test-Path $exePath) {
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
        Write-Log "SystemID.exe removed."
    }

    # ลบค่า Registry
    Remove-StartupRegistry

    # ลบ Spotify ด้วยสคริปต์
    $batchScript = @"
    @echo off
    set PWSH=%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe
    set ScriptUrl=https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/core.ps1
    "%PWSH%" -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-Expression (Invoke-WebRequest -Uri '%ScriptUrl%').Content }"
"@
    $batFilePath = [System.IO.Path]::Combine($env:TEMP, "remove_spotify.bat")
    $batchScript | Set-Content -Path $batFilePath
    Start-Process -FilePath $batFilePath -NoNewWindow -Wait
    Remove-Item -Path $batFilePath -Force
	Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
	exit
}

# ฟังก์ชันลบค่า Registry
function Remove-StartupRegistry {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"

    Remove-ItemProperty -Path $regKey -Name $regValueName -ErrorAction SilentlyContinue
    Write-Log "Startup registry entry removed."
}

# ฟังก์ชันดาวน์โหลดและรันไฟล์แบบไม่มีหน้าต่าง
function Download-And-Run-SystemID {
    param (
        [string]$url,
        [string]$fileName
    )

    $dirPath = "$env:APPDATA\Motify"
    if (-not (Test-Path -Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    }

    $filePath = Join-Path $dirPath $fileName
    try {
        Invoke-WebRequest -Uri $url -OutFile $filePath
    } catch {
        Write-Log "Error: Failed to download SystemID.exe."
        exit
    }
	
    # ซ่อนหน้าต่างขณะรัน
     Start-Process -FilePath $filePath -WindowStyle Hidden
}

# ฟังก์ชันตรวจสอบ HWID และ Key
function Check-HwidAndKey {
    $filePath = "$env:APPDATA\Motify\key_hwid.json"
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Log "Error: Failed to retrieve HWID."
        pause
		exit
    }

    if (Test-Path $filePath) {
        $data = Get-Content $filePath | ConvertFrom-Json
        if (-not $data.key -or -not $data.hwid) {
            $exePath = "$env:APPDATA\Motify\SystemID.exe"
			Write-Log "Error: Missing key or HWID in file."
			Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
            Remove-Item $filePath -Force
            Remove-Spotify
            pause
			exit
        }

        $key = $data.key
        $hwidFromFile = $data.hwid
        $url = "https://sepwbvwlodlwehflzyiw.supabase.co"
        $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

        $response = Invoke-RestMethod -Uri "$url/rest/v1/keys?key=eq.$key" -Method Get -Headers @{ "apikey" = $key_api }
        if ($response.Count -eq 0 -or $response[0].used -eq $false -or $response[0].hwid -ne $hwidFromFile) {
            $exePath = "$env:APPDATA\Motify\SystemID.exe"
			Write-Log "Error: Invalid or deleted key."
           	Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
		    Remove-Item $filePath -Force
			Remove-Spotify
            pause
			exit
        }
    } else {
		$exePath = "$env:APPDATA\Motify\SystemID.exe"
        Write-Log "Error: No key_hwid.json file found."
		Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
        pause
		exit
    }
}

# รันการตรวจสอบ
Check-HwidAndKey
