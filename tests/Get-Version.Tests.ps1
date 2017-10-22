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
        $expected = '1.2.3.4-beta.1+xyz.001'
        $res = ConvertTo-AUVersion $expected

        $res | Should Not BeNullOrEmpty
        $res.Version | Should Be ([version] '1.2.3.4')
        $res.Prerelease | Should BeExactly 'beta.1'
        $res.BuildMetadata | Should BeExactly 'xyz.001'
        $res.ToString() | Should BeExactly $expected
        $res.ToString(2) | Should BeExactly '1.2'
        $res.ToString(-1) | Should BeExactly '1.2.3.4'
    }

    It 'should not convert a non-strict version' {
        { ConvertTo-AUVersion '1.2.3.4a' } | Should Throw
        { ConvertTo-AUVersion 'v1.2.3.4-beta.1+xyz.001' } | Should Throw
    }

    It 'should parse a non strict version' {
        $res = Get-Version 'v1.2.3.4beta.1+xyz.001'

        $res | Should Not BeNullOrEmpty
        $res.Version | Should Be ([version] '1.2.3.4')
        $res.Prerelease | Should BeExactly 'beta.1'
        $res.BuildMetadata | Should BeExactly 'xyz.001'
    }

    $testCases = @(
        @{A = '1.0.0'           ; B = '1.0.0'           ; ExpectedResult = 0}
        @{A = '1.0.0'           ; B = '2.0.0'           ; ExpectedResult = -1}
        @{A = '2.0.0'           ; B = '2.1.0'           ; ExpectedResult = -1}
        @{A = '2.1.0'           ; B = '2.1.1'           ; ExpectedResult = -1}
        @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha'     ; ExpectedResult = 0}
        @{A = '1.0.0-alpha'     ; B = '1.0.0'           ; ExpectedResult = -1}
        @{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.1'   ; ExpectedResult = 0}
        @{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.01'   ; ExpectedResult = 0}
        @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha.1'   ; ExpectedResult = -1}
        @{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.beta'; ExpectedResult = -1}
        @{A = '1.0.0-alpha.beta'; B = '1.0.0-beta'      ; ExpectedResult = -1}
        @{A = '1.0.0-beta'      ; B = '1.0.0-beta.2'    ; ExpectedResult = -1}
        @{A = '1.0.0-beta.2'    ; B = '1.0.0-beta.11'   ; ExpectedResult = -1}
        @{A = '1.0.0-beta.11'   ; B = '1.0.0-rc.1'      ; ExpectedResult = -1}
        @{A = '1.0.0-rc.1'      ; B = '1.0.0'           ; ExpectedResult = -1}
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
