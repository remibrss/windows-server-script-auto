Import-Module ActiveDirectory
Import-Module GroupPolicy
#########################################
# 1. CRÉER LES 3 GPO ET LES LIER AUX OUs
#########################################

$gpoADM   = New-GPO -Name "GPO-ADM-Poste"   -Comment "Administration : H:, sécurité"
$gpoPROF  = New-GPO -Name "GPO-PROF-Poste"  -Comment "Profs : H:, sécurité"
$gpoELEVE = New-GPO -Name "GPO-ELEVE-Poste" -Comment "Élèves : H:, sécurité"

New-GPLink -Name $gpoADM.DisplayName   -Target "OU=Administration,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"
New-GPLink -Name $gpoPROF.DisplayName  -Target "OU=Profs,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"
New-GPLink -Name $gpoELEVE.DisplayName -Target "OU=Eleves,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

Write-Host "==> GPO créées et liées."

###############################################################
# 2. FONCTION : CRÉER SCRIPT LOGON + scripts.ini dans la GPO
###############################################################

function New-LogonScript {
    param([Parameter(Mandatory)]$Gpo)

    $domain = (Get-ADDomain).DNSRoot
    $gpoId  = "{0}" -f $Gpo.Id 

    $logonPath = "\\$domain\SYSVOL\$domain\Policies\$gpoId\User\Scripts\Logon"
    New-Item -Path $logonPath -ItemType Directory -Force | Out-Null

$script = @"
@echo off
REM Mappe H: sur HomeShares
if exist "\\SRV-FS1\HomeShares\%USERNAME%" (
    net use H: "\\SRV-FS1\HomeShares\%USERNAME%" /persistent:no
) else (
    net use H: "\\SRV-FS1\HomeShares\default" /persistent:no
)
exit /B 0
"@

    Set-Content -Path "$logonPath\MapH.bat" -Value $script -Encoding ASCII

    # Scripts.ini
    $scriptIniPath = "\\$domain\SYSVOL\$domain\Policies\$gpoId\User\Scripts\Scripts.ini"
$ini = @"
[Logon]
0CmdLine=MapH.bat
0Parameters=
"@
    Set-Content -Path $scriptIniPath -Value $ini -Encoding ASCII

    Write-Host "==> Script MapH.bat ajouté à $($Gpo.DisplayName)"
}

# Appliquer aux 3 GPO
New-LogonScript -Gpo $gpoADM
New-LogonScript -Gpo $gpoPROF
New-LogonScript -Gpo $gpoELEVE

###########################################################
# 3. FONCTION : ACTIVER FORCE LOGOFF dans GptTmpl.inf
###########################################################

function Enable-ForceLogoff {
    param([Parameter(Mandatory)]$Gpo)

    $domain = (Get-ADDomain).DNSRoot
    $gpoId  = "{0}" -f $Gpo.Id

    $path = "\\$domain\SYSVOL\$domain\Policies\$gpoId\Machine\Microsoft\Windows NT\SecEdit"
    New-Item -Path $path -ItemType Directory -Force | Out-Null

$gpt = @"
[Unicode]
Unicode=yes
[System Access]
ForceLogoffWhenHourExpire = 1
"@

    Set-Content -Path "$path\GptTmpl.inf" -Value $gpt -Encoding ASCII
    Write-Host "==> ForceLogoffWhenHourExpire activé dans $($Gpo.DisplayName)"
}

Enable-ForceLogoff -Gpo $gpoADM
Enable-ForceLogoff -Gpo $gpoPROF
Enable-ForceLogoff -Gpo $gpoELEVE

Write-Host "==> Sécurité appliquée."

##################################################################
# 4. FONCTIONS & APPLICATION DES LOGON HOURS (3 groupes)
##################################################################

function Convert-To-LogonHoursByteArray {
    param([hashtable]$weekSchedule)
    function HourIndex($t){ return [int]$t.Split(':')[0] }
    $days = @("Mon","Tue","Wed","Thu","Fri","Sat","Sun")
    $bytesList = New-Object System.Collections.Generic.List[byte]

    foreach ($day in $days) {
        $bits = @(0)*24
        if ($weekSchedule.ContainsKey($day)) {
            foreach ($period in $weekSchedule[$day]) {
                for ($h = (HourIndex $period.Start); $h -lt (HourIndex $period.End); $h++) {
                    $bits[$h] = 1
                }
            }
        }
        for ($i=0;$i -lt 3;$i++){
            $b=0
            for ($bit=0;$bit -lt 8;$bit++){
                $hour=$i*8+$bit
                if($hour -lt 24 -and $bits[$hour] -eq 1){$b = $b -bor (1 -shl $bit)}
            }
            $bytesList.Add([byte]$b)
        }
    }
    return ,$bytesList.ToArray()
}

function Apply-LogonHoursToGroup {
    param([string]$GroupName,[hashtable]$WeekSchedule)

    $array = Convert-To-LogonHoursByteArray $WeekSchedule
    $users = Get-ADGroupMember $GroupName -Recursive | ? {$_.objectClass -eq "user"}

    foreach ($u in $users) {
        Set-ADUser -Identity $u.SamAccountName -Replace @{LogonHours=$array}
    }

    Write-Host "==> LogonHours appliqués au groupe $GroupName"
}

# Horaires Administration
$AdminSchedule = @{
    Mon=@(@{Start="07:00";End="19:00"}); Tue=@(@{Start="07:00";End="19:00"});
    Wed=@(@{Start="07:00";End="19:00"}); Thu=@(@{Start="07:00";End="19:00"});
    Fri=@(@{Start="07:00";End="19:00"}); Sat=@(); Sun=@()
}

# Horaires Profs
$ProfSchedule = @{
    Mon=@(@{Start="07:00";End="20:00"}); Tue=@(@{Start="07:00";End="20:00"});
    Wed=@(@{Start="07:00";End="20:00"}); Thu=@(@{Start="07:00";End="20:00"});
    Fri=@(@{Start="07:00";End="20:00"}); Sat=@(@{Start="08:00";End="12:00"});
    Sun=@()
}

# Horaires Élèves
$EleveSchedule = @{
    Mon=@(@{Start="08:00";End="18:00"}); Tue=@(@{Start="08:00";End="18:00"});
    Wed=@(@{Start="08:00";End="18:00"}); Thu=@(@{Start="08:00";End="18:00"});
    Fri=@(@{Start="08:00";End="18:00"}); Sat=@(); Sun=@()
}

# Application
Apply-LogonHoursToGroup "MS-Administration" $AdminSchedule
Apply-LogonHoursToGroup "MS-Profs" $ProfSchedule
Apply-LogonHoursToGroup "MS-Eleves" $EleveSchedule


Write-Host "==> TOUT EST APPLIQUÉ."
