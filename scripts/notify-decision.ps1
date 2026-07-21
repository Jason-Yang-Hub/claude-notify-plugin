# notify-decision.ps1 - Claude Code hook 入口（只弹提示，不跳转）
# 触发：Notification / PreToolUse(AskUserQuestion|ExitPlanMode)
# -Clear：UserPromptSubmit / Stop / PostToolUse 清理该会话残留 toast
param([switch]$Clear)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

try {
    Ensure-NotifyDirs

    $reader = New-Object System.IO.StreamReader([System.Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $data = $raw | ConvertFrom-Json
    $sid = [string]$data.session_id
    if (-not $sid) { exit 0 }
    $tag = Get-ToastTag $sid

    if ($Clear) {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        try {
            [Windows.UI.Notifications.ToastNotificationManager]::History.Remove($tag, $script:ToastGroup, $script:Aumid)
        } catch { }
        exit 0
    }

    $eventName = [string]$data.hook_event_name
    $message   = [string]$data.message
    $toolName  = [string]$data.tool_name

    # 过滤 60 秒空闲提醒（idle_prompt），只保留权限等待类
    if ($eventName -eq 'Notification' -and $message -match 'waiting for your input') { exit 0 }

    # 去重：同会话同事件 2 秒窗口
    $lockKey = $eventName
    if ($toolName) { $lockKey = $toolName }
    $lockFile = Join-Path $script:LocksDir ('{0}-{1}.lock' -f $tag, $lockKey)
    if (Test-Path $lockFile) {
        $age = (Get-Date) - (Get-Item $lockFile).LastWriteTime
        if ($age.TotalSeconds -lt 2) { exit 0 }
    }
    Set-Content -Path $lockFile -Value '1' -Force

    # 等待原因文案
    $reason = ''
    if ($toolName -eq 'AskUserQuestion') { $reason = 'Claude 向你提问，等待回答' }
    elseif ($toolName -eq 'ExitPlanMode') { $reason = '计划已就绪，等待批准' }
    elseif ($message) { $reason = '等待确认：' + $message }
    else { $reason = '会话等待你的决策' }
    if ($reason.Length -gt 80) { $reason = $reason.Substring(0, 80) + [char]0x2026 }

    $cwd = [string]$data.cwd
    $project = ''
    if ($cwd) { $project = Split-Path $cwd -Leaf }
    if (-not $project) { $project = 'Claude Code' }

    Show-ClaudeToast -Tag $tag -Title $project -Body $reason -Sticky

    # 顺手清理 7 天前的旧锁
    $cutoff = (Get-Date).AddDays(-7)
    Get-ChildItem $script:LocksDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    exit 0
} catch {
    Write-DebugLog ('notify-decision error: ' + $_.Exception.Message)
    exit 0
}
