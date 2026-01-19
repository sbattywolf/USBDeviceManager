Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Win {
    public delegate bool EnumWinCallback(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWinCallback lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
}
"@

[Win]::EnumWindows({ param($hw,$lp) if ([Win]::IsWindowVisible($hw)) { $sb = New-Object System.Text.StringBuilder 1024; [Win]::GetWindowText($hw,$sb,$sb.Capacity) | Out-Null; $t = $sb.ToString(); if ($t) { Write-Output $t } } return $true }, [IntPtr]::Zero)
