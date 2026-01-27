$PSBoundParameters.Clear()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

. ..\PromptHelper.ps1

Describe 'PromptHelper functions' {
    Context 'Read-NonEmptyString' {
        BeforeAll { $env:NONINTERACTIVE = '1' }
        AfterAll { Remove-Item env:NONINTERACTIVE -ErrorAction SilentlyContinue }

        It 'returns default when AutoAcceptDefault is set in non-interactive mode' {
            $res = Read-NonEmptyString -Prompt 'auto' -Default 'DEFAULT_VAL' -AutoAcceptDefault
            $res | Should Be 'DEFAULT_VAL'
        }
    }

    Context 'Read-ValidatedPath' {
        BeforeAll { $env:NONINTERACTIVE = '1' }
        AfterAll { Remove-Item env:NONINTERACTIVE -ErrorAction SilentlyContinue }

        It 'creates missing file when AutoAcceptDefault + CreateIfMissing + MustExist' {
            $tmp = Join-Path $scriptDir 'tmp-prompthelper-file.txt'
            Remove-Item -Force -ErrorAction SilentlyContinue $tmp

            $res = Read-ValidatedPath -Prompt 'auto-path' -Default $tmp -AutoAcceptDefault -CreateIfMissing -MustExist

            Test-Path $tmp | Should Be $true
            $res | Should Be $tmp

            Remove-Item -Force -ErrorAction SilentlyContinue $tmp
        }
    }
}
