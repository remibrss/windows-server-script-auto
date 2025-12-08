# ==========================================================
# MENU – CREATION UTILISATEURS + AJOUT GROUPES
# ==========================================================

function Set-UsersMenu {
    Clear-Host
    Write-Host "=== MENU CREATION UTILISATEURS AD ===`n"

    Write-Host "1. Créer des utilisateurs"
    Write-Host "2. Ajouter les utilisateurs dans les groupes"
    Write-Host "0. Retour / Quitter`n"

    $choice = Read-Host "Choix"

    switch ($choice) {

        # --------------------------------------------------------
        # 1 — CREATION UTILISATEURS
        # --------------------------------------------------------
        "1" {
            Clear-Host
            Write-Host "=== CREATION D'UTILISATEURS AD ===`n"

            $domain = Read-Host "Nom du domaine (sans suffixe) ex : mediaschool"
            $tld = Read-Host "Suffixe du domaine (ex : local)"
            $root = "DC=$domain,DC=$tld"

            # Mot de passe par défaut
            $pass = ConvertTo-SecureString "P@ssword1" -AsPlainText -Force

            do {
                Clear-Host
                Write-Host "=== Nouvel utilisateur AD ===`n"

                $firstname = Read-Host "Prénom (GivenName)"
                $lastname = Read-Host "Nom (Surname)"
                $ou = Read-Host "OU (Administration | Profs | Eleves)"

                if ($ou -notin @("Administration","Profs","Eleves")) {
                    Write-Host "OU invalide. Choisir : Administration / Profs / Eleves"
                    Pause
                    continue
                }

                $sam = ($firstname.Substring(0,1) + $lastname).ToLower()
                $upn = "$sam@$domain.$tld"
                $fullname = "$firstname $lastname"
                $ouPath = "OU=$ou,OU=Comptes-Utilisateurs,OU=ECOLE,$root"

                Write-Host "`nCréation de : $fullname"
                Write-Host "SamAccountName : $sam"
                Write-Host "UPN            : $upn"
                Write-Host "OU             : $ouPath"

                $confirm = Read-Host "`nConfirmer ? (o/n)"
                if ($confirm -eq "o") {

                    New-ADUser -Name $fullname `
                        -GivenName $firstname `
                        -Surname $lastname `
                        -SamAccountName $sam `
                        -UserPrincipalName $upn `
                        -AccountPassword $pass `
                        -Enabled $true `
                        -Path $ouPath

                    Write-Host "`nUtilisateur créé avec succès !"
                }

                $again = Read-Host "`nCréer un autre utilisateur ? (o/n)"
            }
            while ($again -eq "o")

            Pause
        }

        # --------------------------------------------------------
        # 2 — AJOUT DES UTILISATEURS DANS LES GROUPES
        # --------------------------------------------------------
        "2" {
            Clear-Host
            Write-Host "=== AJOUT DES UTILISATEURS DANS LES GROUPES ===`n"

            # Admins
            Write-Host "`n>>> Ajouter admins au groupe MS-Administration"
            $admins = Read-Host "Saisir les SamAccountName séparés par des virgules ex pour edib saoud : esaoud,..."
            if ($admins.Length -gt 0) {
                Add-ADGroupMember -Identity "MS-Administration" -Members ($admins -split ",")
                Write-Host "Admins ajoutés."
            }

            # Profs
            Write-Host "`n>>> Ajouter profs au groupe MS-Profs"
            $profs = Read-Host "Saisir les SamAccountName séparés par des virgules"
            if ($profs.Length -gt 0) {
                Add-ADGroupMember -Identity "MS-Profs" -Members ($profs -split ",")
                Write-Host "Profs ajoutés."
            }

            # Eleves
            Write-Host "`n>>> Ajouter élèves au groupe MS-Eleves"
            $eleves = Read-Host "Saisir les SamAccountName séparés par des virgules"
            if ($eleves.Length -gt 0) {
                Add-ADGroupMember -Identity "MS-Eleves" -Members ($eleves -split ",")
                Write-Host "Élèves ajoutés."
            }

            Pause
        }

        # --------------------------------------------------------
        "0" { return }
        default {
            Write-Host "Choix invalide."
            Pause
        }
    }

    Set-UsersMenu
}

# Lancer le menu
Set-UsersMenu
