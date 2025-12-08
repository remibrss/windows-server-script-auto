# ==========================================================
# MENU CLI – SERVEUR DE FICHIERS AVEC QUOTAS FSRM (SRV-FS1)
# ==========================================================

Import-Module ServerManager

function Set-FSMenu {
    Clear-Host
    Write-Host "=== MENU SRV-FS1 - PARTAGES + FSRM + QUOTAS ===`n"

    Write-Host "1. Configurer réseau"
    Write-Host "2. Installer File Server + FSRM"
    Write-Host "3. Créer volume D:\Donnees + partage Homes"
    Write-Host "4. Créer dossiers personnels + ACL exclusives"
    Write-Host "5. Configurer quotas FSRM (Admins / Profs / Eleves)"
    Write-Host "6. Tout exécuter"
    Write-Host "0. Quitter`n"

    $choice = Read-Host "Choix"

    switch ($choice) {
        "1" { Set-Network }
        "2" { Install-Roles }
        "3" { Create-Share }
        "4" { Create-PersonalFolders }
        "5" { Configure-Quotas }
        "6" { Run-All }
        "0" { return }
        default { Write-Host "Choix invalide."; Pause }
    }

    Set-FSMenu
}

# ----------------------------------------------------------
# 1 — Réseau
# ----------------------------------------------------------
function Set-Network {
    Clear-Host
    Write-Host "=== CONFIGURATION RESEAU ===`n"

    New-NetIPAddress -InterfaceAlias "Ethernet 2" `
        -IPAddress "192.168.100.20" `
        -PrefixLength 24 `
        -DefaultGateway "192.168.100.1"

    Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" `
        -ServerAddresses "192.168.100.10"

    Write-Host "IP + DNS OK."
    Pause
}

# ----------------------------------------------------------
# 2 — Installer rôles
# ----------------------------------------------------------
function Install-Roles {
    Clear-Host
    Write-Host "=== INSTALLATION ROLES ===`n"

    Install-WindowsFeature FS-FileServer, FS-Resource-Manager

    Write-Host "File Server + FSRM installés."
    Pause
}

# ----------------------------------------------------------
# 3 — Volume + partage Homes
# ----------------------------------------------------------
function Create-Share {
    Clear-Host
    Write-Host "=== CREATION VOLUME + PARTAGE ===`n"

    # Vérifier élévation
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Erreur : exécutez ce script en tant qu'administrateur pour créer des volumes/partages." -ForegroundColor Red
        Pause
        return
    }

    # Volume D:\Donnees
    try {
        if (-not (Test-Path "D:\")) {
            Write-Host "Le lecteur D:\ n'existe pas. Impossible de créer D:\Donnees." -ForegroundColor Yellow
            Pause
            return
        }

        New-Item -Path "D:\" -Name "Donnees" -ItemType Directory -Force | Out-Null
    }
    catch {
        Write-Host "Erreur lors de la création de D:\Donnees : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Assurez-vous que vous avez les droits et que le lecteur D:\ est accessible." -ForegroundColor Yellow
        Pause
        return
    }

    # HomeShares (utiliser un nom de variable non réservé)
    $homesPath = "D:\Donnees\Homes"
    try {
        New-Item -Path $homesPath -ItemType Directory -Force | Out-Null
    }
    catch {
        Write-Host "Erreur lors de la création du répertoire $homesPath : $($_.Exception.Message)" -ForegroundColor Red
        Pause
        return
    }

    # Partage SMB
    try {
        New-SmbShare -Name "Homes" -Path $homesPath -FullAccess "Domain Admins" -ErrorAction Stop
        Write-Host "Partage \\SRV-FS1\Homes créé." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de la création du partage SMB : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Vérifiez que le groupe 'Domain Admins' existe et que la machine est jointe au domaine, ou exécutez en tant qu'administrateur local." -ForegroundColor Yellow
    }

    Pause
}

# ----------------------------------------------------------
# 4 — Dossiers personnels + ACL exclusives
# ----------------------------------------------------------
function Create-PersonalFolders {
    Clear-Host
    Write-Host "=== CREATION DOSSIERS PERSONNELS ===`n"

    $root = "D:\Donnees\Homes"

    # Verifier que le repertoire racine existe
    if (-not (Test-Path $root)) {
        Write-Host "Erreur : $root n'existe pas. Creez d'abord le volume."
        Pause
        return
    }

    # Recuperer les utilisateurs
    Write-Host "Recuperation des utilisateurs..."
    $users = @(Get-ADUser -Filter * -SearchBase "OU=Comptes-Utilisateurs,OU=ECOLE,DC=mediaschool,DC=local" -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty SamAccountName)

    if ($users.Count -eq 0) {
        Write-Host "Erreur : Aucun utilisateur trouve dans l'OU. Verifiez le chemin AD."
        Pause
        return
    }

    Write-Host "Nombre d'utilisateurs trouves : $($users.Count)`n"

    foreach ($u in $users) {
        $path = "$root\$u"

        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory | Out-Null
        }

        # ACL : proprietaire exclusif
        icacls $path /reset
        icacls $path /grant "${u}:(OI)(CI)F"
        icacls $path /grant "Domain Admins:(OI)(CI)F"

        Write-Host "Dossier cree + ACL exclusives : $u"
    }

    Pause
}

# ----------------------------------------------------------
# 5 — FSRM Quotas
# ----------------------------------------------------------
function Configure-Quotas {
    Clear-Host
    Write-Host "=== CONFIGURATION DES QUOTAS FSRM ===`n"

    # ------------------------------
    # Administration : 10 Go
    # ------------------------------
    New-FsrmQuota -Path "D:\Donnees\Homes" `
        -Template "10GB" `
        -Threshold 10GB `
        -Description "Quota Admin 10GB"

    New-FsrmQuotaThreshold -Quota (Get-FsrmQuota -Path "D:\Donnees\Homes") `
        -Percentage 85 `
        -Action Email

    # ------------------------------
    # Profs : 5 Go
    # ------------------------------
    New-FsrmQuota -Path "D:\Donnees\Homes" `
        -Template "5GB" `
        -Threshold 5GB

    New-FsrmQuotaThreshold -Quota (Get-FsrmQuota -Path "D:\Donnees\Homes") `
        -Percentage 85

    # ------------------------------
    # Eleves : 1 Go
    # ------------------------------
    New-FsrmQuota -Path "D:\Donnees\Homes" `
        -Template "1GB" `
        -Threshold 1GB

    New-FsrmQuotaThreshold -Quota (Get-FsrmQuota -Path "D:\Donnees\Homes") `
        -Percentage 85

    Write-Host ">>> Quotas créés (Admins / Profs / Eleves)."
    Pause
}

# ----------------------------------------------------------
# 6 — Tout exécuter
# ----------------------------------------------------------
function Run-All {
    Set-Network
    Install-Roles
    Create-Share
    Create-PersonalFolders
    Configure-Quotas

    Write-Host "`n>>> SERVEUR FS COMPLETEMENT CONFIGURÉ !"
    Pause
}

# ----------------------------------------------------------
# LANCEMENT MENU
# ----------------------------------------------------------
Set-FSMenu

