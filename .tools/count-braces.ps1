param([string]$Path)
$text = Get-Content $Path -Raw
$opens = ($text -split '\{').Count - 1
$closes = ($text -split '\}').Count - 1
Write-Host "Opens: $opens, Closes: $closes"
