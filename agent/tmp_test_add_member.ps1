$o = [PSCustomObject]@{A=1}
$o | Add-Member -MemberType ScriptMethod -Name ContainsKey -Value { param($k) return ($this.PSObject.Properties.Name -contains $k) } -Force
Write-Host "Has ContainsKey: $($o.PSObject.Members.Match('ContainsKey').Count)"
try { Write-Host "Invoke: $($o.ContainsKey('A'))" } catch { Write-Host "Invoke failed: $($_.Exception.Message)" }
