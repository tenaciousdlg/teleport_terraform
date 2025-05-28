<powershell>
# Creates log of script at C:\UserData.log , if there are issues review that file.
Start-Transcript -Path "C:\UserData.log" -Append
$ErrorActionPreference = "Stop"

# --- User Setup ---
$User = "${User}"
$Password = ConvertTo-SecureString "${Password}" -AsPlainText -Force
New-LocalUser -Name $User -Password $Password -FullName $User
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $User
Add-LocalGroupMember -Group "Administrators" -Member $User

# --- Teleport Certificate Download ---
$certPath = "$env:TEMP\teleport.cer"
Invoke-WebRequest -Uri "https://${Domain}/webapi/auth/export?type=windows" -OutFile $certPath

# --- Teleport Installer Download and Install ---
$installerName = "teleport-windows-auth-setup-v${TeleportVersion}-amd64.exe"
$installerPath = "$env:TEMP\$installerName"

Invoke-WebRequest -Uri "https://cdn.teleport.dev/$installerName" -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList "install", "--cert=$certPath", "-r" -Wait -NoNewWindow

# --- Rename Computer and Restart ---
Rename-Computer -NewName "${Env}-desktop" -Force -Restart
</powershell>

<persist>false</persist>
