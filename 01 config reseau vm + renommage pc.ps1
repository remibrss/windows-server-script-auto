# ============================================================
# MENU CLI – CONFIGURATION RESEAU + RENOMMAGE DE LA MACHINE
# ============================================================

function Set-NetworkConfig {
    Clear-Host
    Write-Host "=== Configuration réseau de la VM ===`n"

    Write-Host "1. Afficher les interfaces réseau"
    Write-Host "2. Configurer IP fixe sur interface LAN"
    Write-Host "3. Configurer DNS sur interface LAN"
    Write-Host "4. Vider DNS de l'interface Internet"
    Write-Host "5. Vérifications réseau"
    Write-Host "6. Renommer la machine"
    Write-Host "0. Retour / Quitter`n"

    $choice = Read-Host "Choix"

    switch ($choice) {

        "1" {
            Clear-Host
            Write-Host "=== Interfaces réseau ===`n"
            Get-NetAdapter
            Pause
        }

        "2" {
            Clear-Host
            Write-Host "=== Configuration IP LAN ===`n"
            New-NetIPAddress -InterfaceAlias "Ethernet 2" `
                             -IPAddress "192.168.100.10" `
                             -PrefixLength 24 `
                             -DefaultGateway "192.168.100.1"
            Write-Host "`nIP LAN configurée."
            Pause
        }

        "3" {
            Clear-Host
            Write-Host "=== Configuration DNS LAN ===`n"
            Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" `
                                       -ServerAddresses "192.168.100.10"
            Write-Host "`nDNS LAN configuré."
            Pause
        }

        "4" {
            Clear-Host
            Write-Host "=== Vidage DNS interface Internet ===`n"
            Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses @()
            Write-Host "`nDNS Internet vidés."
            Pause
        }

        "5" {
            Clear-Host
            Write-Host "=== Vérifications réseau ===`n"
            ipconfig /all
            Test-NetConnection -ComputerName 192.168.100.1
            Test-NetConnection -ComputerName 192.168.100.10
            Pause
        }

        "6" {
            Clear-Host
            Write-Host "=== Renommer la machine ===`n"

            $newName = Read-Host "Nom du serveur (ex : SRV-DC1)"

            if ([string]::IsNullOrWhiteSpace($newName)) {
                Write-Host "Nom invalide."
                Pause
            }
            else {
                Rename-Computer -NewName $newName -Restart
            }
        }

        "0" {
            return
        }

        default {
            Write-Host "Choix invalide."
            Pause
        }
    }

    Set-NetworkConfig
}

# Lancer le menu
Set-NetworkConfig
