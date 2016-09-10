import-module $PSScriptRoot\..\AU -force

Describe 'Testing package update' {
    InModuleScope AU {
        Context 'Global variables' {
            Mock Write-Verbose

            $au_Force = $true
            $msg = "Parameter Force set from global variable au_Force: $au_Force"

            It 'sets Force parameter from global variable au_Force if it is not bound' {
                { update -Verbose } | Should Throw 'No nuspec file'
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $msg }

            }

            It "doesn't set Force parameter from global variable au_Force if it is bound" {
                { update -Verbose -Force } | Should Throw 'No nuspec file'
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -ne $msg }
            }

            It 'sets Timeout parameter from global variable au_Timeout if it is not bound' {
                $au_Force   = $null
                $au_Timeout = 50
                $msg        = "Parameter Timeout set from global variable au_Timeout: $au_Timeout"
                { update -Verbose } | Should Throw 'No nuspec file'
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $msg }
            }
        }

        Context 'Nuspec file' {
            pushd $PSScriptRoot\test_package

            It 'loads a nuspec file from the package directory' {
                { update } | Should Not Throw 'No nuspec file'
                $global:Latest.NuspecVersion | Should Be 1.2.3
            }

            popd
        }

        Context 'au_GetLatest' {
            pushd $PSScriptRoot\test_package

            It 'throws if au_GetLatest is not defined' {
                { update } | Should Throw "'au_GetLatest' is not recognized"
            }

            It 'calls au_GetLatest and gets the valid latest version' {
                function global:au_GetLatest { @{Version = 1.3} }
                { update } | Should Not Throw "'au_GetLatest' is not recognized"
                $global:Latest.Version | Should Be 1.3

            }

            It 'calls au_GetLatest and gets the invalid latest version' {
                function global:au_GetLatest { @{Version = '1.3a'} }
                { update } | Should Throw "version doesn't match the pattern"
            }

            popd
        }
    }
}
