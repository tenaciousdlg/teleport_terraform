<#
    .Powershell Examples
    https://gist.github.com/atheiman/ecef955d9352f79c229cd22d56b22629
#>
<powershell>
# Creates log of script at C:\UserData.log , if there are issues review that file. 
Start-Transcript -Path "C:\UserData.log" -Append
# Username and Password
$User = "alice"
# Super strong plane text password here (yes this isn't secure at all)
$Password = ConvertTo-SecureString "+hISisIn>3cur3AnDYoUSh0ul]Us3S0^eThInGElS3|nS+3a>" -AsPlainText -Force
New-LocalUser -Name $User -Password $Password -FullName $User
Add-LocalGroupMember -Group "Remote Desktop Users” -Member $User
Add-LocalGroupMember -Group "Administrators" -Member $User
Invoke-WebRequest -Uri https://teleport.chrisdlg.com/webapi/auth/export?type=windows -OutFile teleport.cer
Invoke-WebRequest -Uri https://cdn.teleport.dev/teleport-windows-auth-setup-v14.1.0-amd64.exe -Outfile teleport-windows-auth-setup.exe
.\teleport-windows-auth-setup.exe install --cert=teleport.cer -r
Rename-Computer -NewName "teleport-desktop-example" -Force -Restart
</powershell>
<persist>false</persist>