###########################################
# 0 — CONFIGURATION RESEAU DE LA VM
###########################################

Get-NetAdapter

# 0.1 — IP FIXE sur interface LAN
New-NetIPAddress -InterfaceAlias "Ethernet 2" `
                 -IPAddress "192.168.100.10" `
                 -PrefixLength 24 `
                 -DefaultGateway "192.168.100.1"

# 0.2 — DNS = serveur lui-même
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" `
                           -ServerAddresses "192.168.100.10"

# 0.3 — Vider DNS interface Internet
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" `
                           -ServerAddresses @()

# Vérifications
ipconfig /all
Test-NetConnection -ComputerName 192.168.100.1
Test-NetConnection -ComputerName 192.168.100.10


###########################################
# 1 — RENOMMER LA MACHINE
###########################################

Rename-Computer -NewName "SRV-DC1" -Restart

###########################################


###########################################
# 2 — INSTALLATION AD DS + DNS
###########################################

Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

Install-ADDSForest `
    -DomainName "mediaschool.local" `
    -DomainNetbiosName "MEDIASCHOOL" `
    -InstallDNS:$true `
    -SafeModeAdministratorPassword (Read-Host -AsSecureString "MotDePasseDSRM") `
    -Force

###########################################


###########################################
# 3 — CREATION DES OU
###########################################

New-ADOrganizationalUnit -Name "ECOLE" -Path "DC=mediaschool,DC=local"

New-ADOrganizationalUnit -Name "Comptes-Utilisateurs" -Path "OU=ECOLE,DC=mediaschool,DC=local"
New-ADOrganizationalUnit -Name "Administration"       -Path "OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"
New-ADOrganizationalUnit -Name "Profs"                -Path "OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"
New-ADOrganizationalUnit -Name "Eleves"               -Path "OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADOrganizationalUnit -Name "Groupes" -Path "OU=ECOLE,DC=mediaschool,DC=local"

###########################################
# 4 — CREATION DES GROUPES
###########################################

New-ADGroup -Name "MS-Administration" -SamAccountName "MS-Administration" `
            -GroupScope Global -GroupCategory Security `
            -Path "OU=Groupes,OU=ECOLE,DC=mediaschool,DC=local"

New-ADGroup -Name "MS-Profs" -SamAccountName "MS-Profs" `
            -GroupScope Global -GroupCategory Security `
            -Path "OU=Groupes,OU=ECOLE,DC=mediaschool,DC=local"

New-ADGroup -Name "MS-Eleves" -SamAccountName "MS-Eleves" `
            -GroupScope Global -GroupCategory Security `
            -Path "OU=Groupes,OU=ECOLE,DC=mediaschool,DC=local"


###########################################
# 5 — CREATION AUTOMATIQUE DES UTILISATEURS
###########################################

# Mot de passe par défaut
$pass = ConvertTo-SecureString "P@ssword1" -AsPlainText -Force

############### ADMINISTRATION ###############
New-ADUser -Name "Admin1 Dupont" -GivenName "Admin1" -Surname "Dupont" `
    -SamAccountName "adupont" -UserPrincipalName "adupont@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Administration,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADUser -Name "Admin2 Durant" -GivenName "Admin2" -Surname "Durant" `
    -SamAccountName "adurant" -UserPrincipalName "adurant@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Administration,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADUser -Name "Admin3 Leroy" -GivenName "Admin3" -Surname "Leroy" `
    -SamAccountName "aleroy" -UserPrincipalName "aleroy@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Administration,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

############### PROFS ###############
New-ADUser -Name "Prof1 Martin" -GivenName "Prof1" -Surname "Martin" `
    -SamAccountName "pmartin" -UserPrincipalName "pmartin@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Profs,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADUser -Name "Prof2 Petit" -GivenName "Prof2" -Surname "Petit" `
    -SamAccountName "ppetit" -UserPrincipalName "ppetit@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Profs,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADUser -Name "Prof3 Bernard" -GivenName "Prof3" -Surname "Bernard" `
    -SamAccountName "pbernard" -UserPrincipalName "pbernard@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Profs,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

############### ELEVES ###############
New-ADUser -Name "Eleve1 Noel" -GivenName "Eleve1" -Surname "Noel" `
    -SamAccountName "enoel" -UserPrincipalName "enoel@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Eleves,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADUser -Name "Eleve2 Caron" -GivenName "Eleve2" -Surname "Caron" `
    -SamAccountName "ecaron" -UserPrincipalName "ecaron@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Eleves,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"

New-ADUser -Name "Eleve3 Roux" -GivenName "Eleve3" -Surname "Roux" `
    -SamAccountName "eroux" -UserPrincipalName "eroux@mediaschool.local" `
    -AccountPassword $pass -Enabled $true `
    -Path "OU=Eleves,OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local"


###########################################
# 6 — AJOUT DES UTILISATEURS DANS LES GROUPES
###########################################

# Administration
Add-ADGroupMember -Identity "MS-Administration" -Members "adupont","adurant","aleroy"

# Profs
Add-ADGroupMember -Identity "MS-Profs" -Members "pmartin","ppetit","pbernard"

# Eleves
Add-ADGroupMember -Identity "MS-Eleves" -Members "enoel","ecaron","eroux"

###########################################
# FIN DU SCRIPT
###########################################
