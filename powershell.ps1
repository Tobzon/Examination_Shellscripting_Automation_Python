#automatisera minst en säkerhetsrelaterad funktion, exempelvis:
#kontroll av privilegierade konton
#analys av Event Viewer
#härdning av settings (t.ex. firewall, audit policies)
#uppdateringsstatus
#inkludera validering, felhantering, beskrivande loggning
#använda moduler eller cmdlets strukturerat




$CsvPath = "C:\Users\tobbi\OneDrive\Skrivbord\Examination_Shellscripting_Automation_Python\SecurityReport.csv"
$BOM = [System.Text.Encoding]::UTF8.GetPreamble()

# ----------------------------
# 1. Privilegierade konton
# ----------------------------
function Check-Users {
    $List = @()
    $PrivGroups = @("Administrators","Domain Admins","Enterprise Admins","Schema Admins")
    foreach ($Group in $PrivGroups) {
        try {
            $Members = Get-LocalGroupMember -Group $Group -ErrorAction Stop
            foreach ($Member in $Members) {
                $List += [PSCustomObject]@{
                    Category    = "Privilegierade konton"
                    SubCategory = $Group
                    Name        = $Member.Name
                    ObjectClass = $Member.ObjectClass
                    Detail      = ""
                }
            }
        }
        catch {
            $List += [PSCustomObject]@{
                Category    = "Privilegierade konton"
                SubCategory = $Group
                Name        = "(Ej tillganglig)"
                ObjectClass = ""
                Detail      = "Fel: $($_.Exception.Message)"
            }
        }
    }
    return $List
}

# ----------------------------
# 2. Event Viewer
# ----------------------------
function Check-EventViewer {
    $List = @()
    $Events = @{
        "Misslyckade inloggningar" = 4625
        "Lyckade inloggningar"     = 4624
        "Kontolasning"             = 4740
        "Privilegieforandring"     = 4672
    }

    foreach ($E in $Events.GetEnumerator()) {
        try {
            $Logs = Get-WinEvent -FilterHashtable @{
                        LogName   = 'Security'
                        Id        = $E.Value
                        StartTime = (Get-Date).AddDays(-7)
                    } -ErrorAction Stop | Select-Object TimeCreated, Id, Message -First 5

            if ($Logs) {
                foreach ($Log in $Logs) {
                    $Detail = ($Log.Message -replace "`r|`n", " ")
                    if ($Detail.Length -gt 200) { $Detail = $Detail.Substring(0,200) + "..." }

                    $List += [PSCustomObject]@{
                        Category    = "Event Viewer"
                        SubCategory = $E.Key
                        Name        = ""
                        ObjectClass = ""
                        Detail      = $Detail
                    }
                }
            } else {
                $List += [PSCustomObject]@{
                    Category    = "Event Viewer"
                    SubCategory = $E.Key
                    Name        = ""
                    ObjectClass = ""
                    Detail      = "Inga handelser hittades"
                }
            }
        }
        catch {
            $List += [PSCustomObject]@{
                Category    = "Event Viewer"
                SubCategory = $E.Key
                Name        = ""
                ObjectClass = ""
                Detail      = "Fel: $($_.Exception.Message)"
            }
        }
    }
    return $List
}

# ----------------------------
# 3. Säkerhetspolicys
# ----------------------------
function Check-Policies {
    $List = @()
    try {
        $NetAccounts = net accounts | Out-String
        $List += [PSCustomObject]@{
            Category    = "Policy"
            SubCategory = "Losenordspolicy"
            Name        = ""
            ObjectClass = ""
            Detail      = $NetAccounts.Trim()
        }
    }
    catch {
        $List += [PSCustomObject]@{
            Category    = "Policy"
            SubCategory = "Losenordspolicy"
            Name        = ""
            ObjectClass = ""
            Detail      = "Fel: $($_.Exception.Message)"
        }
    }

    try {
        $UAC = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" |
               Select-Object EnableLUA, ConsentPromptBehaviorAdmin
        $List += [PSCustomObject]@{
            Category    = "Policy"
            SubCategory = "UAC-status"
            Name        = ""
            ObjectClass = ""
            Detail      = "EnableLUA=$($UAC.EnableLUA), ConsentPromptBehaviorAdmin=$($UAC.ConsentPromptBehaviorAdmin)"
        }
    }
    catch {
        $List += [PSCustomObject]@{
            Category    = "Policy"
            SubCategory = "UAC-status"
            Name        = ""
            ObjectClass = ""
            Detail      = "Fel: $($_.Exception.Message)"
        }
    }

    return $List
}

# ----------------------------
# 4. Windows Update
# ----------------------------
function Check-Updates {
    $List = @()
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $UpdateSession.CreateUpdateSearcher()
        $Result = $Searcher.Search("IsInstalled=0")

        if ($Result.Updates.Count -gt 0) {
            foreach ($Update in $Result.Updates) {
                $List += [PSCustomObject]@{
                    Category    = "Windows Update"
                    SubCategory = "Saknade uppdateringar"
                    Name        = $Update.Title
                    ObjectClass = ""
                    Detail      = "Kritikalitet=$($Update.MsrcSeverity)"
                }
            }
        } else {
            $List += [PSCustomObject]@{
                Category    = "Windows Update"
                SubCategory = "Status"
                Name        = "Alla uppdateringar installerade"
                ObjectClass = ""
                Detail      = ""
            }
        }
    }
    catch {
        $List += [PSCustomObject]@{
            Category    = "Windows Update"
            SubCategory = "Status"
            Name        = "(Ej tillganglig)"
            ObjectClass = ""
            Detail      = "Fel: $($_.Exception.Message)"
        }
    }
    return $List
}


# ----------------------------
# 5. Skriv CSV
# ----------------------------
function Write-CSV {
    param($Results)
    try {
        $CsvText = $Results | ConvertTo-Csv -NoTypeInformation
        [System.IO.File]::WriteAllBytes($CsvPath, $BOM + [System.Text.Encoding]::UTF8.GetBytes($CsvText -join "`r`n"))
        Write-Host "CSV-rapport sparad till: $CsvPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Kunde inte skriva CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ----------------------------
# 7. Main
# ----------------------------
function Main {
    try {
        $Results = @()
        $Results += Check-Users
        $Results += Check-EventViewer
        $Results += Check-Policies
        $Results += Check-Updates

        Write-CSV -Results $Results
    }
    catch {
        Write-Host "Ett ovantat fel intraffade: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Kör scriptet
Main
$CsvPath = "C:\Users\tobbi\OneDrive\Skrivbord\Examination_Shellscripting_Automation_Python\SecurityReport.csv"

if (-not (Test-Path $CsvPath)) {
    Write-Host "CSV-filen hittades inte: $CsvPath" -ForegroundColor Red
    exit
}

$Data = Import-Csv -Path $CsvPath -Encoding UTF8

Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " SAKERHETS- & HARDNINGSRAPPORT" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$Grouped = $Data | Group-Object Category

foreach ($Category in $Grouped) {

    Write-Host "[$($Category.Name)]" -ForegroundColor Yellow
    Write-Host ("-" * ($Category.Name.Length + 2)) -ForegroundColor Yellow

    foreach ($Item in $Category.Group) {

        $Text = ""

        if ($Item.SubCategory) {
            $Text += "$($Item.SubCategory)"
        }

        if ($Item.Name) {
            $Text += " | $($Item.Name)"
        }

        if ($Item.Detail) {
            $Text += " -> $($Item.Detail)"
        }

        switch ($Item.Category) {
            "Windows Update" {
                if ($Item.SubCategory -eq "Saknade uppdateringar") {
                    Write-Host "  [RISK] $Text" -ForegroundColor Red
                } else {
                    Write-Host "  [OK]   $Text" -ForegroundColor Green
                }
            }

            "Brandvägg" {
                Write-Host "  [FW]   $Text" -ForegroundColor Red
            }

            "Privilegierade konton" {
                Write-Host "  [USER] $Text" -ForegroundColor Magenta
            }

            "Event Viewer" {
                Write-Host "  [LOG]  $Text" -ForegroundColor DarkCyan
            }

            "Policy" {
                Write-Host "  [POL]  $Text" -ForegroundColor Cyan
            }

            default {
                Write-Host "  [*]    $Text"
            }
        }
    }

    Write-Host ""
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Slut pa rapport" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan


