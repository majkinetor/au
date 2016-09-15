remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Update-Package' {
    $saved_pwd = $pwd

    function global:get_latest($Version='1.3', $URL='test') {
        "function global:au_GetLatest { @{Version = '$Version'; URL = '$URL'} }" | iex
    }

    function global:seach_replace() {
        "function global:au_SearchReplace { @{} }" | iex
    }

    function global:nuspec_file() { [xml](gc TestDrive:\test_package\test_package.nuspec) }

    BeforeEach {
        cd TestDrive:\
        rm -Recurse -Force TestDrive:\test_package -ea ignore
        cp -Recurse -Force $PSScriptRoot\test_package TestDrive:\test_package
        cd TestDrive:\test_package

        $global:au_Timeout             = 100
        $global:au_Force               = $false
        $global:au_NoHostOutput        = $true
        $global:au_NoCheckUrl          = $true
        $global:au_NoCheckChocoVersion = $true
        $global:au_ChecksumFor         = 'none'

        rv -Scope global Latest -ea ignore
        'BeforeUpdate', 'AfterUpdate' | % { rm "Function:/au_$_" -ea ignore }
        get_latest
        seach_replace
    }

    InModuleScope AU {

        Context 'Updating' {
            It 'automatically calculates the checksum' {
                cp -Recurse -Force $PSScriptRoot\test_package\chocolateyInstall.ps1 TestDrive:\test_package\tools

                $res = update -ChecksumFor 32 6> $null

                $global:Latest.Checksum32 | Should Not BeNullOrEmpty
            }

            It 'updates package when remote version is higher' {
                $res = update

                $res.Updated       | Should Be $true
                $res.RemoteVersion | Should Be 1.3
                $res.Result[-1]    | Should Be 'Package updated'
                (nuspec_file).package.metadata.version | Should Be 1.3
            }

            It "does not update the package when remote version is not higher" {
                get_latest -Version 1.2.3

                $res = update

                $res.Updated       | Should Be $false
                $res.RemoteVersion | Should Be 1.2.3
                $res.Result[-1]    | Should Be 'No new version found'
                (nuspec_file).package.metadata.version | Should Be 1.2.3
            }

            It "does not update the package when it exists on Chocolatey community feed" {
                Mock request {} # feature depends on request throwing exception

                $res = update -NoCheckChocoVersion:$false

                $res.Updated    | Should Be $false
                $res.Result[-1] | Should Match 'it already exists in the Chocolatey community feed'
                (nuspec_file).package.metadata.version | Should Be 1.2.3
            }

            It "updates the package when forced using choco fix notation" {
                get_latest -Version 1.2.3

                $res = update -Force:$true

                $d = (get-date).ToString('yyyyMMdd')
                $res.Updated    | Should Be $true
                $res.Result[-1] | Should Be 'Package updated'
                $res.Result -match 'No new version found, but update is forced' | Should Not BeNullOrEmpty
                (nuspec_file).package.metadata.version | Should Be "1.2.3.$d"
            }

            It "does not use choco fix notation if the package remote version is higher" {
                $res = update -Force:$true

                $res.Updated | Should Be $true
                $res.RemoteVersion | Should Be 1.3
                (nuspec_file).package.metadata.version | Should Be 1.3
            }

            It "searches and replaces given file lines when updating" {

                function global:au_SearchReplace {
                    @{
                        'test_package.nuspec' = @{ '(<releaseNotes>)(.*)(</releaseNotes>)' = '$1test$3' }
                    }
                }

                function global:au_GetLatest {
                    @{ PackageName = 'test'; Version = 1.3  }
                }

                update

                $nu = (nuspec_file).package.metadata
                $nu.releaseNotes | Should Be 'test'
                $nu.id           | Should Be 'test'
                $nu.version      | Should Be 1.3
            }
        }

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

            It 'throws if search string is not found in given file' {
                function global:au_SearchReplace {
                    @{
                        'test_package.nuspec' = @{ 'not existing' = '' }
                    }
                }

                { update } | Should Throw "Search pattern not found: 'not existing'"
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

            It "throws if it can't find the nuspec file in the current directory" {
                cd TestDrive:\
                { update } | Should Throw 'No nuspec file'
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

        Context 'Before and after update' {
            It 'calls au_BeforeUpdate if package is updated' {
                function au_BeforeUpdate { $global:Latest.test = 1 }
                update
                $global:Latest.test | Should Be 1
            }

            It 'calls au_AfterUpdate if package is updated' {
                function au_AfterUpdate { $global:Latest.test = 1 }
                update
                $global:Latest.test | Should Be 1
            }

            It 'doesnt call au_BeforeUpdate if package is not updated' {
                get_latest -Version 1.2.3
                function au_BeforeUpdate { $global:Latest.test = 1 }
                update
                $global:Latest.test | Should BeNullOrEmpty
            }
        }
    }
    cd $saved_pwd
}

