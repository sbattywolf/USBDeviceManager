$path = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-streamed-full.ndjson'
$s = Get-Content -Raw -Path $path
$blocks = $s -split "\r?\n\r?\n+"
Write-Output "Blocks: $($blocks.Count)"
if ($blocks.Count -gt 0) {
	Write-Output "First block length: $($blocks[0].Length)"
	$preview = $blocks[0].Substring(0,[Math]::Min(500,$blocks[0].Length))
	Write-Output "First block preview:\n$preview"
	try { $obj = $blocks[0] | ConvertFrom-Json; Write-Output "First block parsed: token=$($obj.token) path=$($obj.path) line=$($obj.line)" } catch { Write-Output "First block parse failed: $($_.Exception.Message)" }
}
