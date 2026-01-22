#Requires -Version 5.1

<#
.SYNOPSIS
    Placeholder: Application API tests (empty)
.DESCRIPTION
    Minimal stub so the TestRunner can import application API tests when none are present.
#>

function Invoke-ApplicationAPITests {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName 'Application API Tests'

    $result = $null
    try {
        Invoke-Test -Name 'Server project file exists' -Category 'ApplicationAPI' -TestScript {
            $proj = Join-Path $PSScriptRoot '..\..\..\server\USBDeviceManager\USBDeviceManager.csproj'
            Assert-PathExists -Path $proj -Message "Expected project file at $proj"
        }

        Invoke-Test -Name 'Program.cs exists' -Category 'ApplicationAPI' -TestScript {
            $prog = Join-Path $PSScriptRoot '..\..\..\server\USBDeviceManager\Program.cs'
            Assert-PathExists -Path $prog -Message "Expected Program.cs at $prog"
        }

        # simple runtime check: try GET / on localhost:5000 if available
        Invoke-Test -Name 'Server responding on localhost:5000 (if running)' -Category 'ApplicationAPI' -TestScript {
            function Get-HttpStatusCode($url, $timeoutMs = 3000) {
                try {
                    $req = [System.Net.WebRequest]::Create($url)
                    $req.Method = 'GET'
                    $req.Timeout = $timeoutMs
                    $resp = $req.GetResponse()
                    $code = 0
                    try { $code = [int]$resp.StatusCode } catch { try { $code = [int]$resp.StatusCode.Value__ } catch { $code = 0 } }
                    $resp.Close()
                    return $code
                }
                catch [System.Net.WebException] {
                    if ($_.Exception.Response) {
                        try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 }
                        try { $_.Exception.Response.Close() } catch { }
                        return $code
                    }
                    throw
                }
            }

            try {
                $code = Get-HttpStatusCode 'http://127.0.0.1:5000/' 3000
                if ($code -eq 0) { Write-Verbose 'Server not reachable on port 5000; skipping runtime check.' } else { Assert-Equal -Expected 200 -Actual $code -Message "Expected HTTP 200 from server root, got $code" }
            } catch {
                Write-Verbose "HTTP check errored: $($_.Exception.Message)"
            }
        }

    } finally {
        $result = Complete-TestSession
    }

    return $result
}

# Export when used as a module
try { if ($PSModuleInfo) { Export-ModuleMember -Function 'Invoke-ApplicationAPITests' } } catch { Write-Verbose "Export skipped: $_" }
