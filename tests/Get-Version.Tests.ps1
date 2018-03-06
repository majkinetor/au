remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Get-Version' -Tag getversion {
    InModuleScope AU {
        It 'should convert a strict version' {
            $expectedVersionStart = '1.2'
            $expectedVersion = "$expectedVersionStart.3.4"
            # for now, chocolatey does only support SemVer v1 (no dot separated identifiers in pre-release):
            $expectedPrerelease = 'beta1'
            $expectedBuildMetadata = 'xyz001'
            # here is the SemVer v2 equivalent:
            #$expectedPrerelease = 'beta.1'
            #$expectedBuildMetadata = 'xyz.001'
            $expected = "$expectedVersion-$expectedPrerelease+$expectedBuildMetadata"
            $res = ConvertTo-AUVersion $expected

            $res | Should Not BeNullOrEmpty
            $res.Version | Should Be ([version] $expectedVersion)
            $res.Prerelease | Should BeExactly $expectedPrerelease
            $res.BuildMetadata | Should BeExactly $expectedBuildMetadata
            $res.ToString() | Should BeExactly $expected
            $res.ToString(2) | Should BeExactly $expectedVersionStart
            $res.ToString(-1) | Should BeExactly $expectedVersion
        }

        It 'should not convert a non-strict version' {
            { ConvertTo-AUVersion '1.2.3.4a' } | Should Throw
            { ConvertTo-AUVersion 'v1.2.3.4-beta.1+xyz.001' } | Should Throw
        }

        It 'should parse a non strict version' {
            $expectedVersion = "1.2.3.4"
            # for now, chocolatey does only support SemVer v1 (no dot separated identifiers in pre-release):
            $expectedPrerelease = 'beta1'
            $expectedBuildMetadata = 'xyz001'
            # here is the SemVer v2 equivalent:
            #$expectedPrerelease = 'beta.1'
            #$expectedBuildMetadata = 'xyz.001'
            $res = Get-Version "v$expectedVersion$expectedPrerelease+$expectedBuildMetadata"

            $res | Should Not BeNullOrEmpty
            $res.Version | Should Be ([version] $expectedVersion)
            $res.Prerelease | Should BeExactly $expectedPrerelease
            $res.BuildMetadata | Should BeExactly $expectedBuildMetadata
        }

        $testCases = @(
            @{A = '1.9.0'           ; B = '1.9.0'           ; ExpectedResult = 0}
            @{A = '1.9.0'           ; B = '1.10.0'          ; ExpectedResult = -1}
            @{A = '1.10.0'          ; B = '1.11.0'          ; ExpectedResult = -1}
            @{A = '1.0.0'           ; B = '2.0.0'           ; ExpectedResult = -1}
            @{A = '2.0.0'           ; B = '2.1.0'           ; ExpectedResult = -1}
            @{A = '2.1.0'           ; B = '2.1.1'           ; ExpectedResult = -1}
            @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha'     ; ExpectedResult = 0}
            @{A = '1.0.0-alpha'     ; B = '1.0.0'           ; ExpectedResult = -1}
            # for now, chocolatey does only support SemVer v1 (no dot separated identifiers in pre-release):
            @{A = '1.0.0-alpha1'    ; B = '1.0.0-alpha1'    ; ExpectedResult = 0}
            @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha1'    ; ExpectedResult = -1}
            @{A = '1.0.0-alpha1'    ; B = '1.0.0-alphabeta' ; ExpectedResult = -1}
            @{A = '1.0.0-alphabeta' ; B = '1.0.0-beta'      ; ExpectedResult = -1}
            @{A = '1.0.0-beta'      ; B = '1.0.0-beta2'     ; ExpectedResult = -1}
            @{A = '1.0.0-beta2'     ; B = '1.0.0-rc1'       ; ExpectedResult = -1}
            @{A = '1.0.0-rc1'       ; B = '1.0.0'           ; ExpectedResult = -1}
            # here is the SemVer v2 equivalent:
            #@{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.1'   ; ExpectedResult = 0}
            #@{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.01'  ; ExpectedResult = 0}
            #@{A = '1.0.0-alpha'     ; B = '1.0.0-alpha.1'   ; ExpectedResult = -1}
            #@{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.beta'; ExpectedResult = -1}
            #@{A = '1.0.0-alpha.beta'; B = '1.0.0-beta'      ; ExpectedResult = -1}
            #@{A = '1.0.0-beta'      ; B = '1.0.0-beta.2'    ; ExpectedResult = -1}
            #@{A = '1.0.0-beta.2'    ; B = '1.0.0-beta.11'   ; ExpectedResult = -1}
            #@{A = '1.0.0-beta.11'   ; B = '1.0.0-rc.1'      ; ExpectedResult = -1}
            #@{A = '1.0.0-rc.1'      ; B = '1.0.0'           ; ExpectedResult = -1}
            @{A = '1.0.0'           ; B = '1.0.0+1'         ; ExpectedResult = 0}
            @{A = '1.0.0+1'         ; B = '1.0.0+2'         ; ExpectedResult = 0}
            @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha+1'   ; ExpectedResult = 0}
            @{A = '1.0.0-alpha+1'   ; B = '1.0.0-alpha+2'   ; ExpectedResult = 0}
        )

        It 'should compare 2 versions successfully' -TestCases $testCases { param([string] $A, [string] $B, [int] $ExpectedResult)
            $VersionA = ConvertTo-AUVersion $A
            $VersionB = ConvertTo-AUVersion $B
            if ($ExpectedResult -gt 0 ) {
                $VersionA | Should BeGreaterThan $VersionB
            } elseif ($ExpectedResult -lt 0 ) {
                $VersionA | Should BeLessThan $VersionB
            } else {
                $VersionA | Should Be $VersionB
            }
        }

        $testCases = @(
            @{Value = '1.2'}
            @{Value = '1.2-beta+003'}
            @{Value = [AUVersion] '1.2'}
            @{Value = [AUVersion] '1.2-beta+003'}
            @{Value = [version] '1.2'}
            @{Value = [regex]::Match('1.2', '^(.+)$').Groups[1]}
            @{Value = [regex]::Match('1.2-beta+003', '^(.+)$').Groups[1]}
            )

        It 'converts from any type of values' -TestCases $testCases { param($Value)
            $version = [AUVersion] $Value
            $version | Should Not BeNullOrEmpty
        }

        $testCases = @(
            @{Value = '1.2-beta.3'}
            @{Value = '1.2+xyz.4'}
            @{Value = '1.2-beta.3+xyz.4'}
            )

        It 'does not convert semver v2' -TestCases $testCases { param($Value, $ExpectedResult)
            { [AUVersion] $Value } | Should Throw 'Invalid version'
        }

        $testCases = @(
            @{ExpectedResult = '5.4.9'    ; Delimiter = '-' ; Value = 'http://dl.airserver.com/pc32/AirServer-5.4.9-x86.msi'}
            @{ExpectedResult = '1.24.0-beta2'               ; Value = 'https://github.com/atom/atom/releases/download/v1.24.0-beta2/AtomSetup.exe'}
            @{ExpectedResult = '2.4.0.24-beta'              ; Value = 'https://github.com/gurnec/HashCheck/releases/download/v2.4.0.24-beta/HashCheckSetup-v2.4.0.24-beta.exe'}
            @{ExpectedResult = '2.0.9'                      ; Value = 'http://www.ltr-data.se/files/imdiskinst_2.0.9.exe'}
            @{ExpectedResult = '17.6'     ; Delimiter = '-' ; Value = 'http://mirrors.kodi.tv/releases/windows/win32/kodi-17.6-Krypton-x86.exe'}
            @{ExpectedResult = '0.70.2'                     ; Value = 'https://github.com/Nevcairiel/LAVFilters/releases/download/0.70.2/LAVFilters-0.70.2-Installer.exe'}
            @{ExpectedResult = '2.2.0-1'                    ; Value = 'https://files.kde.org/marble/downloads/windows/Marble-setup_2.2.0-1_x64.exe'}
            @{ExpectedResult = '2.3.2'                      ; Value = 'https://github.com/sabnzbd/sabnzbd/releases/download/2.3.2/SABnzbd-2.3.2-win-setup.exe'}
            @{ExpectedResult = '1.9'      ; Delimiter = '-' ; Value = 'http://download.serviio.org/releases/serviio-1.9-win-setup.exe'}
            @{ExpectedResult = '0.17.0'                     ; Value = 'https://github.com/Stellarium/stellarium/releases/download/v0.17.0/stellarium-0.17.0-win32.exe'}
            @{ExpectedResult = '5.24.3.1'                   ; Value = 'http://strawberryperl.com/download/5.24.3.1/strawberry-perl-5.24.3.1-32bit.msi'}
            @{ExpectedResult = '3.5.4'                      ; Value = 'https://github.com/SubtitleEdit/subtitleedit/releases/download/3.5.4/SubtitleEdit-3.5.4-Setup.zip'}
            # for now, chocolatey does only support SemVer v1 (no dot separated identifiers in pre-release):
            @{ExpectedResult = '1.2.3-beta4'                ; Value = 'v 1.2.3 beta 4'}
            @{ExpectedResult = '1.2.3-beta3'                ; Value = 'Last version: 1.2.3 beta 3.'}
            # here is the SemVer v2 equivalent:
            #@{ExpectedResult = '1.2.3-beta.4'                ; Value = 'v 1.2.3 beta 4'}
            #@{ExpectedResult = '1.2.3-beta.3'                ; Value = 'Last version: 1.2.3 beta 3.'}
            )

        It 'should parse any non strict version' -TestCases $testCases { param($Value, $Delimiter, $ExpectedResult)
            $version = Get-Version $Value -Delimiter $Delimiter
            $version | Should Be ([AUVersion] $ExpectedResult)
        }
    }
}
