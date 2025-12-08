# ==========================================================
# MENU CLI – GESTION DES GPO (Postes + Scripts + Sécurité + Horaires)
# ==========================================================

Import-Module ActiveDirectory
Import-Module GroupPolicy

function Set-GPOMenu {
    Clear-Host
    Write-Host "=== MENU GESTION DES GPO ===`n"

    Write-Host "1. Créer les 3 GPO et les lier aux OUs"
    Write-Host "2. Générer les scripts logon (MapH.bat + scripts.ini)"
    Write-Host "3. Activer ForceLogoffWhenHourExpire"
    Write-Host "4. Appliquer les horaires de connexion (logon hours)"
    Write-Host "5. Tout exécuter (auto)"
    Write-Host "0. Quitter`n"

    $choice = Read-Host "Choix"

    switch ($choice) {

        "1" { Create-GPOs }
        "2" { Create-LogonScripts }
        "3" { Enable-ForceLogoffAll }
        "4" { Apply-AllLogonHours }
        "5" { Run-AllGPO }
        "0" { return }

        default {
            Write-Host "Choix invalide."
            Pause
        }
    }

    Set-GPOMenu
}

# ==========================================================
# 1 — CREATION DES GPO + LINK
# ==============================================================

function Create-GPOs {
    Write-Host "`n>>> Création des GPO..."

    $gpoADM   = New-GPO -Name "GPO-ADM-Poste"   -Comment "Administration : H:, sécurité"
    $gpoPROF  = New-GPO -Name "GPO-PROF-Poste"  -Comment "Profs : H:, sécurité"
    $gpoELEVE = New-GPO -Name "GPO-ELEVE-Poste" -Comment "Élèves : H:, sécurité"

    New-GPLink -Name $gpoADM.DisplayName   -Target "OU=Administration,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"
    New-GPLink -Name $gpoPROF.DisplayName  -Target "OU=Profs,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"
    New-GPLink -Name $gpoELEVE.DisplayName -Target "OU=Eleves,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

    Write-Host ">>> GPO créées et liées."
    Pause
}

# ==========================================================
# 2 — CREATION DES SCRIPTS LOGON
# ==============================================================

function Create-LogonScripts {

    function New-LogonScript {
        param([Parameter(Mandatory)]$Gpo)

        $domain = (Get-ADDomain).DNSRoot
        $gpoId  = "{0}" -f $Gpo.Id

        $logonPath = "\\$domain\SYSVOL\$domain\Policies\$gpoId\User\Scripts\Logon"
        New-Item -Path $logonPath -ItemType Directory -Force | Out-Null

$script = @"
@echo off
if exist "\\SRV-FS1\HomeShares\%USERNAME%" (
    net use H: "\\SRV-FS1\HomeShares\%USERNAME%" /persistent:no
) else (
    net use H: "\\SRV-FS1\HomeShares\default" /persistent:no
)
exit /B 0
"@

        Set-Content -Path "$logonPath\MapH.bat" -Value $script -Encoding ASCII

        $ini = @"
[Logon]
0CmdLine=MapH.bat
0Parameters=
"@

        Set-Content -Path "$logonPath\Scripts.ini" -Value $ini -Encoding ASCII

        Write-Host ">>> Script logon ajouté pour $($Gpo.DisplayName)"
    }

    $gpos = Get-GPO -All | Where-Object { $_.DisplayName -match "GPO-(ADM|PROF|ELEVE)-Poste" }

    foreach ($g in $gpos) {
        New-LogonScript -Gpo $g
    }

    Pause
}

# ==========================================================
# 3 — FORCE LOGOFF
# ==============================================================

function Enable-ForceLogoffAll {

    function Enable-ForceLogoff {
        param([Parameter(Mandatory)]$Gpo)

        $domain = (Get-ADDomain).DNSRoot
        $gpoId = "{0}" -f $Gpo.Id

        $path = "\\$domain\SYSVOL\$domain\Policies\$gpoId\Machine\Microsoft\Windows NT\SecEdit"
        New-Item -Path $path -ItemType Directory -Force | Out-Null

$gpt = @"
[Unicode]
Unicode=yes
[System Access]
ForceLogoffWhenHourExpire = 1
"@

        Set-Content -Path "$path\GptTmpl.inf" -Value $gpt -Encoding ASCII
        Write-Host ">>> ForceLogoff activé pour $($Gpo.DisplayName)"
    }

    $gpos = Get-GPO -All | Where-Object { $_.DisplayName -match "GPO-(ADM|PROF|ELEVE)-Poste" }

    foreach ($g in $gpos) { Enable-ForceLogoff -Gpo $g }

    Pause
}

# ==========================================================
# 4 — APPLIQUER LES HORAIRES (LOGON HOURS)
# ==============================================================

function Apply-AllLogonHours {

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
                    if ($hour -lt 24 -and $bits[$hour] -eq 1){$b = $b -bor (1 -shl $bit)}
                }
                $bytesList.Add([byte]$b)
            }
        }

        return ,$bytesList.ToArray()
    }

    function Apply-LogonHoursToGroup {
        param([string]$GroupName,[hashtable]$WeekSchedule)

        $array = Convert-To-LogonHoursByteArray $WeekSchedule
        $users = Get-ADGroupMember $GroupName -Recursive | Where-Object {$_.objectClass -eq "user"}

        foreach ($u in $users) {
            Set-ADUser -Identity $u.SamAccountName -Replace @{LogonHours=$array}
        }

        Write-Host ">>> Horaires appliqués au groupe $GroupName"
    }

    # Horaires
    $AdminSchedule = @{
        Mon=@(@{Start="07:00";End="19:00"}); Tue=@(@{Start="07:00";End="19:00"});
        Wed=@(@{Start="07:00";End="19:00"}); Thu=@(@{Start="07:00";End="19:00"});
        Fri=@(@{Start="07:00";End="19:00"}); Sat=@(); Sun=@()
    }

    $ProfSchedule = @{
        Mon=@(@{Start="07:00";End="20:00"}); Tue=@(@{Start="07:00";End="20:00"});
        Wed=@(@{Start="07:00";End="20:00"}); Thu=@(@{Start="07:00";End="20:00"});
        Fri=@(@{Start="07:00";End="20:00"}); Sat=@(@{Start="08:00";End="12:00"});
        Sun=@()
    }

    $EleveSchedule = @{
        Mon=@(@{Start="08:00";End="18:00"}); Tue=@(@{Start="08:00";End="18:00"});
        Wed=@(@{Start="08:00";End="18:00"}); Thu=@(@{Start="08:00";End="18:00"});
        Fri=@(@{Start="08:00";End="18:00"}); Sat=@(); Sun=@()
    }

    Apply-LogonHoursToGroup "MS-Administration" $AdminSchedule
    Apply-LogonHoursToGroup "MS-Profs" $ProfSchedule
    Apply-LogonHoursToGroup "MS-Eleves" $EleveSchedule

    Pause
}

# ==========================================================
# 5 — EXECUTION COMPLETE
# ==============================================================

function Run-AllGPO {
    Create-GPOs
    Create-LogonScripts
    Enable-ForceLogoffAll
    Apply-AllLogonHours
    Write-Host "`n>>> TOUT EST APPLIQUÉ !"
    Pause
}

# ----------------------------------------------------------
# LANCEMENT DU MENU
# ----------------------------------------------------------
Set-GPOMenu
