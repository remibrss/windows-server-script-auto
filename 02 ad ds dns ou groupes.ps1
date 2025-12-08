# ==========================================================
# MENU CLI – INSTALLATION AD DS / DNS / OU / GROUPES
# ==========================================================

function Set-ADDSMenu {
    Clear-Host
    Write-Host "=== MENU AD DS / DNS / OU / GROUPES ===`n"

    Write-Host "1. Installer AD DS + DNS"
    Write-Host "2. Créer les Unités d’Organisation (OU)"
    Write-Host "3. Créer les Groupes AD"
    Write-Host "0. Retour / Quitter`n"

    $choice = Read-Host "Choix"

    switch ($choice) {

        # --------------------------------------------------------
        # 1 — Installation AD DS + DNS
        # --------------------------------------------------------
        "1" {
            Clear-Host
            Write-Host "=== INSTALLATION AD DS + DNS ===`n"

            Write-Host "Installation des rôles AD DS + DNS..."
            Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

            Write-Host "`nConfiguration de la forêt..."
            $domainName = Read-Host "Nom du domaine (FQDN), ex : mediaschool.local"
            $netbios = Read-Host "Nom NetBIOS, ex : MEDIASCHOOL"
            $dsrmPass = Read-Host -AsSecureString "Mot de passe DSRM"

            Install-ADDSForest `
                -DomainName $domainName `
                -DomainNetbiosName $netbios `
                -InstallDNS:$true `
                -SafeModeAdministratorPassword $dsrmPass `
                -Force

            Pause
        }

        # --------------------------------------------------------
        # 2 — Création des OU
        # --------------------------------------------------------
        "2" {
            Clear-Host
            Write-Host "=== CREATION DES UO (OU) ===`n"

            $domain = Read-Host "Nom du domaine sans suffixe (ex : mediaschool)"
            $tld = Read-Host "Suffixe du domaine (ex : local)"

            # Racine AD
            $root = "DC=$domain,DC=$tld"

            Write-Host "`nCréation des OU..."

            New-ADOrganizationalUnit -Name "ECOLE" -Path $root

            New-ADOrganizationalUnit -Name "Comptes-Utilisateurs" -Path "OU=ECOLE,$root"
            New-ADOrganizationalUnit -Name "Administration"       -Path "OU=Comptes-Utilisateurs,OU=ECOLE,$root"
            New-ADOrganizationalUnit -Name "Profs"                -Path "OU=Comptes-Utilisateurs,OU=ECOLE,$root"
            New-ADOrganizationalUnit -Name "Eleves"               -Path "OU=Comptes-Utilisateurs,OU=ECOLE,$root"

            New-ADOrganizationalUnit -Name "Groupes" -Path "OU=ECOLE,$root"

            Write-Host "`nOU créées avec succès."
            Pause
        }

        # --------------------------------------------------------
        # 3 — Création des groupes
        # --------------------------------------------------------
        "3" {
            Clear-Host
            Write-Host "=== CREATION DES GROUPES AD ===`n"

            $domain = Read-Host "Nom du domaine sans suffixe (ex : mediaschool)"
            $tld = Read-Host "Suffixe du domaine (ex : local)"
            $root = "DC=$domain,DC=$tld"

            Write-Host "`nCréation des groupes..."

            New-ADGroup -Name "MS-Administration" -SamAccountName "MS-Administration" `
                -GroupScope Global -GroupCategory Security `
                -Path "OU=Groupes,OU=ECOLE,$root"

            New-ADGroup -Name "MS-Profs" -SamAccountName "MS-Profs" `
                -GroupScope Global -GroupCategory Security `
                -Path "OU=Groupes,OU=ECOLE,$root"

            New-ADGroup -Name "MS-Eleves" -SamAccountName "MS-Eleves" `
                -GroupScope Global -GroupCategory Security `
                -Path "OU=Groupes,OU=ECOLE,$root"

            Write-Host "`nGroupes créés avec succès."
            Pause
        }

        # --------------------------------------------------------
        "0" { return }
        default {
            Write-Host "Choix invalide."
            Pause
        }
    }

    Set-ADDSMenu
}

# Lancer le menu
Set-ADDSMenu
