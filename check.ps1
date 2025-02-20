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

# ฟังก์ชันสำหรับลบไฟล์ SystemID.exe และ Registry
function Remove-Spotify {
    # 🔴 ลบไฟล์ SystemID.exe ออกจากโฟลเดอร์
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
    if (Test-Path $exePath) {
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
        Write-Log "SystemID.exe removed from folder."
    } else {
        Write-Log "SystemID.exe not found in folder."
    }

    # 🔴 ลบ Registry
    Remove-StartupRegistry
    Write-Log "Registry entry for SystemID removed."

    # บังคับปิด PowerShell
    Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
    exit
}

# ฟังก์ชันเพิ่มโปรแกรมใน Registry สำหรับเริ่มต้นระบบ
function Add-StartupRegistry {
    $exePath = "$env:APPDATA\Motify\SystemID.exe"

    # ตรวจสอบว่าไฟล์ .exe มีอยู่หรือไม่
    if (-not (Test-Path $exePath)) {
        Write-Log "Error: $exePath not found for startup."
        exit
    }

    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"

    # เพิ่มคีย์ใน Registry
    Set-ItemProperty -Path $regKey -Name $regValueName -Value $exePath
    Write-Log "SystemID.exe added to startup registry."
}

# ฟังก์ชันลบโปรแกรมจาก Registry
function Remove-StartupRegistry {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"

    # ตรวจสอบว่ามี registry อยู่หรือไม่ก่อนลบ
    if (Get-ItemProperty -Path $regKey -Name $regValueName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $regKey -Name $regValueName -ErrorAction SilentlyContinue
        Write-Log "Success: SystemID.exe removed from startup registry."
    } else {
        Write-Log "Info: SystemID.exe registry entry not found, skipping removal."
    }
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
                Write-Log "Error: Invalid or deleted key. Removing related files."
                Remove-Spotify
                exit
            } else {
                Write-Log "Success: Key and HWID match."
                Add-StartupRegistry  # ✅ ถ้า Key และ HWID ถูกต้อง ให้เพิ่ม Registry
            }
        }
        catch {
            Write-Log "Error: Failed to connect to Supabase API."
            Remove-Spotify
            exit
        }
    } else {
        Write-Log "Error: No key_hwid.json file found."
        Remove-Spotify
        exit
    }
}

# เรียกใช้งานฟังก์ชัน
Check-HwidAndKey
