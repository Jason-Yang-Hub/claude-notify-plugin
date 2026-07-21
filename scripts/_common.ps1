# _common.ps1 - 供 notify-decision.ps1 / setup-aumid.ps1 dot-source
# PS 5.1 兼容

$script:NotifyDataDir = Join-Path $env:LOCALAPPDATA 'claude-notify'
$script:LocksDir      = Join-Path $script:NotifyDataDir 'locks'
$script:LogFile       = Join-Path $script:NotifyDataDir 'debug.log'
$script:Aumid         = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
$script:ToastGroup    = 'claude-notify'

function Ensure-NotifyDirs {
    foreach ($d in @($script:NotifyDataDir, $script:LocksDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

function Write-DebugLog {
    param([string]$Message)
    try {
        if ((Test-Path $script:LogFile) -and ((Get-Item $script:LogFile).Length -gt 1MB)) {
            Remove-Item $script:LogFile -Force
        }
        $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
    } catch { }
}

function Get-ToastTag {
    param([string]$SessionId)
    $clean = $SessionId -replace '[^0-9a-zA-Z-]', ''
    if ($clean.Length -gt 16) { return $clean.Substring(0, 16) }
    return $clean
}

# 弹 toast。-Sticky = reminder 常驻横幅 + 「忽略」按钮（右上角 ✕ 与忽略均可关闭）
function Show-ClaudeToast {
    param(
        [string]$Tag,
        [string]$Title,
        [string]$Body,
        [switch]$Sticky
    )
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $t = [System.Security.SecurityElement]::Escape($Title)
    $b = [System.Security.SecurityElement]::Escape($Body)

    $toastAttrs = ''
    $actionsXml = ''
    if ($Sticky) {
        $toastAttrs = ' scenario="reminder"'
        $actionsXml = '<actions><action content="忽略" arguments="dismiss" activationType="system"/></actions>'
    }

    $xml = '<toast{0}><visual><binding template="ToastGeneric"><text>{1}</text><text>{2}</text></binding></visual>{3}</toast>' -f $toastAttrs, $t, $b, $actionsXml

    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($xml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification($doc)
    if ($Tag) {
        $toast.Tag = $Tag
        $toast.Group = $script:ToastGroup
    }
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:Aumid).Show($toast)
}
