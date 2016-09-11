remove-module AU
import-module $PSScriptRoot\..\AU

Describe 'Testing package update' {
    InModuleScope AU {
        pushd $PSScriptRoot\test_package
        $global:au_NoHostOutput = $true

        Context 'Checks' {

            It 'reads the valid latest version' {
                function global:au_GetLatest { @{Version = 1.3} }
                { update } | Should Not Throw "'au_GetLatest' is not recognized"
                $global:Latest.Version | Should Be 1.3

            }

            It 'throws if latest version is invalid' {
                function global:au_GetLatest { @{Version = '1.3a'} }
                { update } | Should Throw "version doesn't match the pattern"
            }

            #It 'supports semantic version' {
                #function global:au_GetLatest { @{Version = '1.0.1-alpha'} }
                #{ update } | Should Not Throw "version doesn't match the pattern"
            #}

            function global:au_GetLatest { @{Version = '1.3'; URL32 = 'test'} }

            It 'throws if latest URL is non existent' {
                { update } | Should Throw "Can't validate latest test_package URL"
            }

            It 'throws if latest URL ContentType is text/html' {
                Mock request { @{ ContentType = 'text/html' } }
                { update } | Should Throw "Latest test_package URL content type is text/html"
            }

            It 'quits if updated package version already exist in Chocolatey community feed' {
                $res = update -NoCheckUrl
                $res.Result[-1] | Should Match "New version is available but it already exists in the Chocolatey community feed"
            }
        }
        popd
        exit

        Context 'Global variables' {
            Mock Write-Verbose

            $global:au_Force = $true
            $msg = "Parameter Force set from global variable au_Force: $au_Force"

            It 'sets Force parameter from global variable au_Force if it is not bound' {
                { update -Verbose } | Should Throw 'au_GetLatest failed'
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $msg }

            }

            It "doesn't set Force parameter from global variable au_Force if it is bound" {
                { update -Verbose -Force } | Should Throw 'au_GetLatest failed'
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -ne $msg }
            }

            It 'sets Timeout parameter from global variable au_Timeout if it is not bound' {
                rv -Scope Global au_Force
                $global:au_Timeout = 50
                $msg = "Parameter Timeout set from global variable au_Timeout: $au_Timeout"
                { update -Verbose } | Should Throw 'au_GetLatest failed'
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $msg }
            }

            'Force', 'Timeout' | % { rv -Scope Global "au_$_" }
        }

        Context 'Nuspec file' {

            It 'loads a nuspec file from the package directory' {
                { update } | Should Not Throw 'No nuspec file'
                $global:Latest.NuspecVersion | Should Be 1.2.3
            }

        }

        Context 'au_GetLatest' {

            It 'throws if au_GetLatest is not defined' {
                { update } | Should Throw "'au_GetLatest' is not recognized"
            }


            It "throws if au_GetLatest doesn't return HashTable" {
                $return_value = @(1)
                function global:au_GetLatest { $return_value }
                { update } | Should Throw "doesn't return a HashTable"
                $return_value = @()
                { update } | Should Throw "returned nothing"
            }

            It "rethrows if au_GetLatest throws" {
                function global:au_GetLatest { throw 'test' }
                { update } | Should Throw "test"
            }
        }

        popd
    }
}
