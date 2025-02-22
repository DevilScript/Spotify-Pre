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

    # สร้างข้อความ log ที่มีเวลาปัจจุบัน
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
    
    # บันทึกข้อความลงในไฟล์ log
    Add-Content -Path $logFilePath -Value $logMessage
}

# ฟังก์ชันลบไฟล์ Spotify และข้อมูลที่เกี่ยวข้อง
function Remove-Spotify {    
    $exePath = "$env:APPDATA\Motify\SystemID.exe"
    $exeMPath = "$env:APPDATA\Microsoft\SystemID.exe"
    
    # ลบไฟล์ .exe หากมี
    if (Test-Path $exePath) {
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
        Write-Log "System: E Removed"
    }

    # ลบ Registry entry สำหรับ Startup
    $registryKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $registryKeyName = "SystemID"
    $key = Get-ItemProperty -Path $registryKeyPath -Name $registryKeyName -ErrorAction SilentlyContinue

    if ($key) {
        Remove-ItemProperty -Path $registryKeyPath -Name $registryKeyName -Force
        Write-Log "System: R Removed"
    } else {
        Write-Log "System: R not found"
    }

    # ลบไฟล์ Spotify (ถ้ามี)
    $spotifyPath = "$env:APPDATA\Spotify"
    if (Test-Path $spotifyPath) {
        Remove-Item -Path $spotifyPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "System: Files have been deleted"
		Write-Log "///////////////////////////////////////////////////////////////////////////////////////"

    } else {
        Write-Log "System: Files Not found in PC"
		Write-Log "///////////////////////////////////////////////////////////////////////////////////////"

    }

    # สร้างไฟล์ .bat สำหรับการลบ Spotify และรัน core.ps1
    $batchScript = @"
@echo off
set PWSH=%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe
set ScriptUrl=https://raw.githubusercontent.com/DevilScript/Spotify-Pre/refs/heads/main/core.ps1

"%PWSH%" -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-Expression (Invoke-WebRequest -Uri '%ScriptUrl%').Content }"
"@

    # สร้างและรันไฟล์ .bat
    $batFilePath = [System.IO.Path]::Combine($env:TEMP, "remove_spotify.bat")
    $batchScript | Set-Content -Path $batFilePath
    Start-Process -FilePath $batFilePath -NoNewWindow -Wait

    # ลบไฟล์ .bat หลังจากทำงานเสร็จ
    Remove-Item -Path $batFilePath -Force
    Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue
    Write-Log "///////////////////////////////////////////////////////////////////////////////////////"
    exit
}

# ฟังก์ชันเพิ่มโปรแกรมใน Registry สำหรับเริ่มต้นระบบ
function Add-StartupRegistry {

    $exePath = "$env:APPDATA\Motify\SystemID.exe"
    $exeMPath = "$env:APPDATA\Microsoft\SystemID.exe"

    # ตรวจสอบว่าไฟล์ .exe มีอยู่หรือไม่
    if (-not (Test-Path $exePath)) {
        Write-Log "Error: E Not found for up"
        exit
    }

    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "SystemID"
    $regValueName2 = "Microsofted"

    # เพิ่มคีย์ใน Registry
    Set-ItemProperty -Path $regKey -Name $regValueName -Value $exePath
    Set-ItemProperty -Path $regKey -Name $regValueName2 -Value $exeMPath
    Write-Log "System: R added"
}

# ฟังก์ชันตรวจสอบวันหมดอายุ
function Check-ExpiryDate {
    param (
        [string]$key
    )

    # ดึงข้อมูลจาก Supabase
    $url = "https://sepwbvwlodlwehflzyiw.supabase.co/rest/v1/keys?key=eq.$key"
    $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

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

            # 🔴 **ส่งข้อมูลไปยัง `expired_log` ใน Supabase**
            $logData = @{
                key   = $key
                hwid  = $hwid
                time  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }

            try {
                $logResponse = Invoke-RestMethod -Uri "https://sepwbvwlodlwehflzyiw.supabase.co/rest/v1/expired_log" `
                    -Method POST `
                    -Headers @{ "apikey" = $key_api } `
                    -Body ($logData | ConvertTo-Json -Depth 10) `
                    -ContentType "application/json"

            }
            catch {
                Write-Log "Error: Failed to log expired key"
            }

            # 🔴 **อัปเดตสถานะ Key เป็น Expired**
            $updateData = @{ status = "Expired" }

            try {
                $updateResponse = Invoke-RestMethod -Uri "$url" -Method PATCH -Headers @{ "apikey" = $key_api } `
                    -Body ($updateData | ConvertTo-Json) -ContentType "application/json"


            }
            catch {
                Write-Log "Error: Failed to update status"
            }

            # 🔴 **ลบ Key ออกจากฐานข้อมูล**
            try {
                $deleteResponse = Invoke-RestMethod -Uri $url -Method DELETE -Headers @{ "apikey" = $key_api }
				Write-Log "System: Key has Expired"
				Write-Log "System: Key | $key | has been deleted from the DATA"
            }
            catch {
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



# ฟังก์ชันตรวจสอบ HWID และ Key
function Check-HwidAndKey {
    Write-Log "------------------------ Log Entry: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ------------------------"
    Write-Log "Start: Checking HWID/Key/Files"

    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $filePath = "$appDataPath\Motify\key_hwid.json"

    # รับค่า HWID ของเครื่อง
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Log "Error: Failed to retrieve HWID"
        exit
    }

    # ตรวจสอบไฟล์ JSON ว่ามีข้อมูล key และ hwid
    if (Test-Path $filePath) {
        $data = Get-Content $filePath | ConvertFrom-Json
        if (-not $data.key -or -not $data.hwid) {
            Write-Log "Error: Key/HWID missing in the json file"
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }

        $key = $data.key
        $hwidFromFile = $data.hwid
		
        # ✅ **เช็ควันหมดอายุของ Key**
        if (Check-ExpiryDate -key $key) {
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        } else {
        }

        # ✅ **เช็ค Key กับ HWID**
        $url = "https://sepwbvwlodlwehflzyiw.supabase.co/rest/v1/keys?key=eq.$key"
        $key_api = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdidndsb2Rsd2VoZmx6eWl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5MTM3NjIsImV4cCI6MjA1NTQ4OTc2Mn0.kwtXM0A0O-7YfuIqoGX8uCfWxT3gLi96RY9XuxM_rAI"

        try {
            $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "apikey" = $key_api }

            if ($response.Count -eq 0 -or $response[0].used -eq $false -or $response[0].hwid -ne $hwidFromFile) {
                Write-Log "Error: Key/HWID has been deleted from the DATA"
                Remove-Item $filePath -Force
                Remove-Spotify
                exit
            } else {
                Write-Log "Success: Key/HWID match"
                Add-StartupRegistry  # ✅ ถ้า Key และ HWID ถูกต้อง ให้เพิ่ม Registry
            }
        }
        catch {
            Write-Log "Error: Failed to connect to DATA"
            Remove-Item $filePath -Force
            Remove-Spotify
            exit
        }
    } else {
        Write-Log "Error: No key_hwid.json file found"
        Remove-Item $filePath -Force
        Remove-Spotify
        exit
    }

    Write-Log "///////////////////////////////////////////////////////////////////////////////////////"
}

# ✅ เรียกใช้งานฟังก์ชัน
Check-HwidAndKey
