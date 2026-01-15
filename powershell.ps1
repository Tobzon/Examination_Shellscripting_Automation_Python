#automatisera minst en säkerhetsrelaterad funktion, exempelvis:
#kontroll av privilegierade konton
#analys av Event Viewer
#härdning av settings (t.ex. firewall, audit policies)
#uppdateringsstatus
#inkludera validering, felhantering, beskrivande loggning
#använda moduler eller cmdlets strukturerat


# ==============================
# Säkerhets- & Härdningskontroll med CSV-export
# ==============================

$CsvPath = "C:\Users\tobbi\OneDrive\Skrivbord\Examination_Shellscripting_Automation_Python\SecurityReport.csv"
$BOM = [System.Text.Encoding]::UTF8.GetPreamble()
$Results = @()  # Array för alla rader

# ----------------------------
# 1. Privilegierade konton
# ----------------------------
$PrivGroups = @("Administrators","Domain Admins","Enterprise Admins","Schema Admins")
foreach ($Group in $PrivGroups) {
    try {
        $Members = Get-LocalGroupMember -Group $Group -ErrorAction Stop
        foreach ($Member in $Members) {
            $Results += [PSCustomObject]@{
                Category = "Privilegierade konton"
                SubCategory = $Group
                Name = $Member.Name
                ObjectClass = $Member.ObjectClass
                Detail = ""
            }
        }
    }
    catch {
        $Results += [PSCustomObject]@{
            Category = "Privilegierade konton"
            SubCategory = $Group
            Name = "(Ej tillgänglig)"
            ObjectClass = ""
            Detail = "Gruppen finns ej eller kräver domänåtkomst"
        }
    }
}

# ----------------------------
# 2. Event Viewer-analys
# ----------------------------
$Events = @{
    "Misslyckade inloggningar" = 4625
    "Lyckade inloggningar"    = 4624
    "Kontolåsning"            = 4740
    "Privilegieförändring"    = 4672
}

foreach ($E in $Events.GetEnumerator()) {
    $Logs = Get-WinEvent -FilterHashtable @{
        LogName='Security'
        Id=$E.Value
        StartTime=(Get-Date).AddDays(-7)
    } -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message -First 5

    if ($Logs) {
        foreach ($Log in $Logs) {
            $Results += [PSCustomObject]@{
                Category = "Event Viewer"
                SubCategory = $E.Key
                Name = ""
                ObjectClass = ""
                Detail = "$($Log.TimeCreated) | ID: $($Log.Id) | $($Log.Message)"
            }
        }
    } else {
        $Results += [PSCustomObject]@{
            Category = "Event Viewer"
            SubCategory = $E.Key
            Name = ""
            ObjectClass = ""
            Detail = "Inga händelser hittades"
        }
    }
}

# ----------------------------
# 3. Brandvägg & härdning
# ----------------------------

# ----------------------------
# Viktiga brandväggsregler (strikt)
# ----------------------------


#$FwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
#foreach ($Fw in $FwProfiles) {
#    $Results += [PSCustomObject]@{
#        Category = "Brandvägg"
#        SubCategory = $Fw.Name
#        Name = "Status"
#        ObjectClass = ""
#        Detail = "Enabled=$($Fw.Enabled), Inbound=$($Fw.DefaultInboundAction), Outbound=$($Fw.DefaultOutboundAction)"
#    }
#}

##$ImportantPorts = @(3389, 445, 5985, 5986)  # RDP, SMB, WinRM

$FwRules = Get-NetFirewallRule |
    Where-Object {
        $_.Enabled -eq "True" -and
        $_.Direction -eq "Inbound" -and
        $_.Action -eq "Allow"
    } | ForEach-Object {
        $Port = (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_ |
                 Select-Object -ExpandProperty LocalPort -ErrorAction SilentlyContinue)
        
        # Hantera "Any" och nummer separat
        if ($Port -eq "Any" -or ($Port -as [int] -and $ImportantPorts -contains [int]$Port)) {
            $_ | Select-Object DisplayName, Profile, Direction, Action, @{Name="Port";Expression={$Port}}
        }
    }

    foreach ($Rule in $FwRules) {
    $Results += [PSCustomObject]@{
        Category = "Brandvägg"
        SubCategory = "Viktiga inkommande regler"
        Name = $Rule.DisplayName
        ObjectClass = ""
        Detail = "Profil=$($Rule.Profile), Port=$($Rule.Port), Action=$($Rule.Action)"
    }
}

#$FwRules = Get-NetFirewallRule |
#    Where-Object {$_.Enabled -eq "True" -and $_.Direction -eq "Inbound" -and $_.Action -eq "Allow"} |
#    Select-Object DisplayName, Profile
#foreach ($Rule in $FwRules) {
#    $Results += [PSCustomObject]@{
#        Category = "Brandvägg"
#        SubCategory = "Öppna regler"
#        Name = $Rule.DisplayName
#        ObjectClass = ""
#        Detail = "Profil=$($Rule.Profile)"
#
#    }
#}


# ----------------------------
# 4. Säkerhetspolicys
# ----------------------------
# Lösenordspolicy
$NetAccounts = net accounts | Out-String
$Results += [PSCustomObject]@{
    Category = "Policy"
    SubCategory = "Lösenordspolicy"
    Name = ""
    ObjectClass = ""
    Detail = $NetAccounts.Trim()
}

# UAC
$UAC = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" | 
       Select-Object EnableLUA, ConsentPromptBehaviorAdmin
$Results += [PSCustomObject]@{
    Category = "Policy"
    SubCategory = "UAC-status"
    Name = ""
    ObjectClass = ""
    Detail = "EnableLUA=$($UAC.EnableLUA), ConsentPromptBehaviorAdmin=$($UAC.ConsentPromptBehaviorAdmin)"
}

# ----------------------------
# 5. Uppdateringsstatus
# ----------------------------
try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $Searcher = $UpdateSession.CreateUpdateSearcher()
    $Result = $Searcher.Search("IsInstalled=0")

    if ($Result.Updates.Count -gt 0) {
        foreach ($Update in $Result.Updates) {
            $Results += [PSCustomObject]@{
                Category = "Windows Update"
                SubCategory = "Saknade uppdateringar"
                Name = $Update.Title
                ObjectClass = ""
                Detail = "Kritikalitet=$($Update.MsrcSeverity)"
            }
        }
    } else {
        $Results += [PSCustomObject]@{
            Category = "Windows Update"
            SubCategory = "Status"
            Name = "Alla uppdateringar installerade"
            ObjectClass = ""
            Detail = ""
        }
    }
}
catch {
    $Results += [PSCustomObject]@{
        Category = "Windows Update"
        SubCategory = "Status"
        Name = "(Ej tillgänglig)"
        ObjectClass = ""
        Detail = "Kunde inte kontrollera uppdateringar"
    }
}


# Konvertera resultat till CSV-text
$CsvText = $Results | ConvertTo-Csv -NoTypeInformation

# Skriv BOM + CSV-text till fil
[System.IO.File]::WriteAllBytes($CsvPath, $BOM + [System.Text.Encoding]::UTF8.GetBytes($CsvText -join "`r`n"))

Write-Host "CSV-rapport sparad till: $CsvPath" -ForegroundColor Green

# ----------------------------
# Exportera CSV med korrekt svenska tecken
# ----------------------------
#$Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8BOM

#Write-Host "CSV-rapport sparad till: $CsvPath" -ForegroundColor Green

