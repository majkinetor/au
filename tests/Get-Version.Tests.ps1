remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Get-Version' -Tag getversion {
    $saved_pwd = $pwd

    BeforeEach {
        cd TestDrive:\
        rm -Recurse -Force TestDrive:\test_package -ea ignore
        cp -Recurse -Force $PSScriptRoot\test_package TestDrive:\test_package
    }

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
        # for now, chocolatey does only support SemVer v1 (no dot separated identifiers in pre-release):
        { ConvertTo-AUVersion 'v1.2.3.4-beta1+xyz001' } | Should Throw
        # here is the SemVer v2 equivalent:
        #{ ConvertTo-AUVersion 'v1.2.3.4-beta.1+xyz.001' } | Should Throw
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

    cd $saved_pwd
}
