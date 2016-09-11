remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Testing package update' {
    function get_latest($Version='1.3', $URL='test') {
        "function global:au_GetLatest { @{Version = '$Version'; URL = '$URL'} }" | iex
    }

    function seach_replace() {
        "function global:au_SearchReplace { @{} }" | iex
    }

    BeforeEach {
        cd c:
        rm -Recurse TestDrive:\test_package -ea ignore
        cp -Recurse -Force $PSScriptRoot\test_package TestDrive:\test_package
        cd TestDrive:\test_package

        $global:au_Timeout             = 100
        $global:au_Force               = $false
        $global:au_NoHostOutput        = $true
        $global:au_NoCheckUrl          = $true
        $global:au_NoCheckChocoVersion = $true

        rv -Scope global Latest -ea ignore
        get_latest
        seach_replace
    }

    InModuleScope AU {
        Context 'Checks' {
            It 'reads the valid latest version' {
                $res = update
                $global:Latest.Version | Should Be 1.3
            }

            It 'throws if latest version is invalid' {
                get_latest -Version 1.3a
                { update } | Should Throw "version doesn't match the pattern"
            }

            #It 'supports semantic version' {
                #function global:au_GetLatest { @{Version = '1.0.1-alpha'} }
                #{ update } | Should Not Throw "version doesn't match the pattern"
            #}


            It 'throws if latest URL is non existent' {
                { update -NoCheckUrl:$false } | Should Throw "Can't validate latest test_package URL"
            }

            It 'throws if latest URL ContentType is text/html' {
                Mock request { @{ ContentType = 'text/html' } }
                { update -NoCheckUrl:$false } | Should Throw "Latest test_package URL content type is text/html"
            }

            It 'quits if updated package version already exist in Chocolatey community feed' {
                $res = update -NoCheckChocoVersion:$false
                $res.Result[-1] | Should Match "New version is available but it already exists in the Chocolatey community feed"
            }
        }

        Context 'Global variables' {
            Mock Write-Verbose


            It 'sets Force parameter from global variable au_Force if it is not bound' {
                $global:au_Force = $true
                $msg = "Parameter Force set from global variable au_Force: $au_Force"
                update -Verbose
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $msg }

            }

            It "doesn't set Force parameter from global variable au_Force if it is bound" {
                $global:au_Force = $true
                $msg = "Parameter Force set from global variable au_Force: $au_Force"
                update -Verbose -Force:$false
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -ne $msg }
            }

            It 'sets Timeout parameter from global variable au_Timeout if it is not bound' {
                $global:au_Timeout = 50
                $msg = "Parameter Timeout set from global variable au_Timeout: $au_Timeout"
                update -Verbose
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $msg }
            }

        }

        Context 'Nuspec file' {

            It 'loads a nuspec file from the package directory' {
                { update } | Should Not Throw 'No nuspec file'
                $global:Latest.NuspecVersion | Should Be 1.2.3
            }

        }

        Context 'au_GetLatest' {

            It 'throws if au_GetLatest is not defined' {
                rm Function:/au_GetLatest
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

        Context 'Updating' {
            It 'updates package when remote version is higher' {
                $res = update
                $res.Updated | Should Be $true
                $res.Result[-1] | Should Be 'Package updated'
            }

            It "does not update the package when remote version is not higher" {
                get_latest -Version 1.1
                $res = update
                $res.Updated | Should Be $false
                $res.Result[-1] | Should Be 'No new version found'
            }

            It "does not update the package when it exists on Chocolatey community feed" {
                Mock request {}
                $res = update -NoCheckChocoVersion:$false
                $res.Updated | Should Be $false
                $res.Result[-1] | Should Match 'it already exists in the Chocolatey community feed'

            }
        }

    }
}
