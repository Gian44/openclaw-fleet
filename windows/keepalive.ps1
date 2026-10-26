# Keeps the WSL2 Ubuntu distro (and therefore the OpenClaw gateway systemd service) alive.
# WSL2 shuts a distro down ~8 s after its last attached process exits; a `sleep infinity`
# session pins it. Runs at logon, restarts itself if it dies.
#
# Launched through `conhost.exe --headless` so no console window appears at logon.
# (The task's -Hidden setting only hides the task in Task Scheduler, not its window.)
$action   = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless wsl.exe -d Ubuntu -- sleep infinity"
$trigger  = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -ExecutionTimeLimit ([TimeSpan]::Zero) -Hidden -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "OpenClaw-WSL-KeepAlive" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName "OpenClaw-WSL-KeepAlive"
(Get-ScheduledTask -TaskName "OpenClaw-WSL-KeepAlive").State

# To turn it off:  Disable-ScheduledTask -TaskName "OpenClaw-WSL-KeepAlive"
