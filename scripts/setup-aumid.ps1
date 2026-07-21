# setup-aumid.ps1 - 幂等注册 AUMID + 开始菜单快捷方式（unpackaged app toast 显示前提）
# 无参数：由 SessionStart hook 调用，已配置则秒退；-Uninstall：清理
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$AumidKey     = 'HKCU:\Software\Classes\AppUserModelId\' + $script:Aumid
$LegacyProto  = 'HKCU:\Software\Classes\claude-jump'
$ShortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Claude Code.lnk'

function Create-AumidShortcut {
    param([string]$LnkPath, [string]$AppId)
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
namespace ClaudeNotifySetup {
  [ComImport, Guid("00021401-0000-0000-C000-000000000046")] public class CShellLink { }
  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
  public interface IShellLinkW {
    void GetPath(StringBuilder f, int c, IntPtr p, uint g); void GetIDList(out IntPtr p); void SetIDList(IntPtr p);
    void GetDescription(StringBuilder n, int c); void SetDescription(string n);
    void GetWorkingDirectory(StringBuilder d, int c); void SetWorkingDirectory(string d);
    void GetArguments(StringBuilder a, int c); void SetArguments(string a);
    void GetHotkey(out ushort h); void SetHotkey(ushort h);
    void GetShowCmd(out int s); void SetShowCmd(int s);
    void GetIconLocation(StringBuilder i, int c, out int n); void SetIconLocation(string i, int n);
    void SetRelativePath(string r, uint d); void Resolve(IntPtr h, uint f); void SetPath(string f);
  }
  [StructLayout(LayoutKind.Sequential, Pack = 4)] public struct PropertyKey { public Guid fmtid; public uint pid; }
  [StructLayout(LayoutKind.Explicit)] public struct PropVariant { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; }
  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
  public interface IPropertyStore {
    void GetCount(out uint c); void GetAt(uint i, out PropertyKey k);
    void GetValue(ref PropertyKey k, out PropVariant v); void SetValue(ref PropertyKey k, ref PropVariant v); void Commit();
  }
  public static class Maker {
    public static void Create(string lnk, string target, string args, string aumid) {
      var link = (IShellLinkW)new CShellLink();
      link.SetPath(target); link.SetArguments(args); link.SetShowCmd(7);
      var store = (IPropertyStore)link;
      var key = new PropertyKey { fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5 };
      var pv = new PropVariant { vt = 31, p = Marshal.StringToCoTaskMemUni(aumid) };
      store.SetValue(ref key, ref pv); store.Commit(); Marshal.FreeCoTaskMem(pv.p);
      ((IPersistFile)link).Save(lnk, true);
    }
  }
}
'@
    $target = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    [ClaudeNotifySetup.Maker]::Create($LnkPath, $target, '-NoProfile -WindowStyle Hidden -Command exit', $AppId)
}

try {
    if ($Uninstall) {
        if (Test-Path $AumidKey)     { Remove-Item $AumidKey -Recurse -Force }
        if (Test-Path $LegacyProto)  { Remove-Item $LegacyProto -Recurse -Force }
        if (Test-Path $ShortcutPath) { Remove-Item $ShortcutPath -Force }
        Write-Output '[claude-notify] AUMID / shortcut removed.'
        exit 0
    }

    # 幂等快退：AUMID 键与快捷方式都在则无需重建
    if ((Test-Path $AumidKey) -and (Test-Path $ShortcutPath)) { exit 0 }

    # 清理遗留的跳转协议注册（旧独立版本残留）
    if (Test-Path $LegacyProto) { Remove-Item $LegacyProto -Recurse -Force }

    New-Item -Path $AumidKey -Force | Out-Null
    Set-ItemProperty -Path $AumidKey -Name 'DisplayName' -Value 'Claude Code'
    Create-AumidShortcut $ShortcutPath $script:Aumid
    exit 0
} catch {
    Write-DebugLog ('setup-aumid error: ' + $_.Exception.Message)
    exit 0
}
