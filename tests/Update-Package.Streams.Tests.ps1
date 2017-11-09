remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU -force

Describe 'Update-Package using streams' -Tag updatestreams {
    $saved_pwd = $pwd

    function global:get_latest([string] $Version, [string] $URL32, [string] $Checksum32) {
        $streams = @{
            '1.4' = @{ Version = '1.4-beta1'; URL32 = 'test.1.4-beta1' }
            '1.3' = @{ Version = '1.3.1'; URL32 = 'test.1.3.1' }
            '1.2' = @{ Version = '1.2.4'; URL32 = 'test.1.2.4' }
        }
        if ($Version) {
            $stream = (ConvertTo-AUVersion $Version).ToString(2)
            if (!$URL32) {
                $URL32 = if ($streams.$stream) { $streams.$stream.URL32 } else { "test.$Version" }
            }
            $streams.Remove($stream)
            $s = @{ Version = $Version; URL32 = $URL32 }
            if ($Checksum32) { $s += @{ Checksum32 = $Checksum32 } }
            $streams.Add($stream, $s)
        }
        $command = "function global:au_GetLatest { @{ Fake = 1; Streams = [ordered] @{`n"
        foreach ($item in ($streams.Keys| sort { ConvertTo-AUVersion $_ } -Descending)) {
            $command += "'$item' = @{Version = '$($streams.$item.Version)'; URL32 = '$($streams.$item.URL32)'"
            if ($streams.$item.Checksum32) { $command += "; Checksum32 = '$($streams.$item.Checksum32)'" }
            $command += "}`n"
        }
        $command += "} } }"
        $command | iex
    }

    function global:seach_replace() {
        "function global:au_SearchReplace { @{} }" | iex
    }

    function global:nuspec_file() { [xml](gc TestDrive:\test_package_with_streams\test_package_with_streams.nuspec) }

    function global:json_file() { (gc TestDrive:\test_package_with_streams\test_package_with_streams.json) | ConvertFrom-Json }

    BeforeEach {
        cd $TestDrive
        rm -Recurse -Force TestDrive:\test_package_with_streams -ea ignore
        cp -Recurse -Force $PSScriptRoot\test_package_with_streams TestDrive:\test_package_with_streams
        cd $TestDrive\test_package_with_streams

        $global:au_Timeout             = 100
        $global:au_Force               = $false
        $global:au_Include             = ''
        $global:au_NoHostOutput        = $true
        $global:au_NoCheckUrl          = $true
        $global:au_NoCheckChocoVersion = $true
        $global:au_ChecksumFor         = 'none'
        $global:au_WhatIf              = $false
        $global:au_NoReadme            = $false

        rv -Scope global Latest -ea ignore
        'BeforeUpdate', 'AfterUpdate' | % { rm "Function:/au_$_" -ea ignore }
        get_latest
        seach_replace
    }

    InModuleScope AU {

        Context 'Updating' {

            It 'can set description from README.md' {
                $readme = 'dummy readme & test'
                '','', $readme | Out-File $TestDrive\test_package_with_streams\README.md
                $res = update

                $res.Result -match 'Setting package description from README.md' | Should Be $true
                (nuspec_file).package.metadata.description.InnerText.Trim()     | Should Be $readme
            }

            It 'can set stream specific descriptions from README.md' {
                get_latest -Version 1.4.0

                $readme = 'dummy readme & test: '
                function au_BeforeUpdate { param([AUPackage] $package)
                    '','', ($readme + $package.RemoteVersion) | Out-File $TestDrive\test_package_with_streams\README.md
                }
                function au_AfterUpdate { param([AUPackage] $package)
                    $package.NuspecXml.package.metadata.description.InnerText.Trim() | Should Be ($readme + $package.RemoteVersion)
                }

                $res = update
                $res.Result -match 'Setting package description from README.md' | Should Not BeNullOrEmpty
            }

            It 'does not set description from README.md with NoReadme parameter' {
                $readme = 'dummy readme & test'
                '','', $readme | Out-File $TestDrive\test_package_with_streams\README.md
                $res = update -NoReadme

                $res.Result -match 'Setting package description from README.md' | Should BeNullOrEmpty
                (nuspec_file).package.metadata.description | Should Be 'This is a test package with streams for Pester'
            }

            It 'can backup and restore using WhatIf' {
                get_latest -Version 1.2.3
                $global:au_Force = $true
                $global:au_Version = '1.0'
                $global:au_WhatIf = $true
                $res = update -ChecksumFor 32 6> $null

                $res.Updated       | Should Be $true
                $res.RemoteVersion | Should Be '1.0'
                (nuspec_file).package.metadata.version | Should Be 1.2.3
                (json_file).'1.2'  | Should Be 1.2.3
                (json_file).'1.3'  | Should Be 1.3.1
                (json_file).'1.4'  | Should Be 1.4-beta1
            }

            It 'can let user override the version of the latest stream' {
                get_latest -Version 1.2.3
                $global:au_Force = $true
                $global:au_Version = '1.0'

                $res = update -ChecksumFor 32 6> $null

                $res.Updated       | Should Be $true
                $res.RemoteVersion | Should Be '1.0'
                (json_file).'1.2'  | Should Be 1.2.3
                (json_file).'1.3'  | Should Be 1.3.1
                (json_file).'1.4'  | Should Be 1.0
            }

            It 'can let user override the version of a specific stream' {
                get_latest -Version 1.2.3
                $global:au_Force = $true
                $global:au_Include = '1.2'
                $global:au_Version = '1.0'

                $res = update -ChecksumFor 32 6> $null

                $res.Updated       | Should Be $true
                $res.RemoteVersion | Should Be '1.0'
                (json_file).'1.2'  | Should Be 1.0
                (json_file).'1.3'  | Should Be 1.3.1
                (json_file).'1.4'  | Should Be 1.4-beta1
            }

            It 'automatically verifies the checksum' {
                $choco_path = gcm choco.exe | % Source
                $choco_hash = Get-FileHash $choco_path -Algorithm SHA256 | % Hash

                get_latest -Version 1.2.4 -URL32 $choco_path -Checksum32 $choco_hash

                $res = update -ChecksumFor 32 6> $null
                $res.Result -match 'hash checked for 32 bit version' | Should Be $true
            }

            It 'automatically calculates the checksum' {
                update -ChecksumFor 32 -Include 1.2 6> $null

                $global:Latest.Checksum32     | Should Not BeNullOrEmpty
                $global:Latest.ChecksumType32 | Should Be 'sha256'
                $global:Latest.Checksum64     | Should BeNullOrEmpty
                $global:Latest.ChecksumType64 | Should BeNullOrEmpty
            }

            It 'updates package when remote version is higher' {
                $res = update

                $res.Updated      | Should Be $true
                $res.Streams.'1.2'.RemoteVersion       | Should Be 1.2.4
                $res.Streams.'1.3'.RemoteVersion       | Should Be 1.3.1
                $res.Streams.'1.4'.RemoteVersion       | Should Be 1.4-beta1
                $res.Result[-1]   | Should Be 'Package updated'
                (nuspec_file).package.metadata.version | Should Be 1.2.4
                (json_file).'1.2' | Should Be 1.2.4
                (json_file).'1.3' | Should Be 1.3.1
                (json_file).'1.4' | Should Be 1.4-beta1
            }

            It 'updates package when multiple remote versions are higher' {
                get_latest -Version 1.4.0

                $res = update

                $res.Updated      | Should Be $true
                $res.Streams.'1.2'.RemoteVersion | Should Be 1.2.4
                $res.Streams.'1.3'.RemoteVersion | Should Be 1.3.1
                $res.Streams.'1.4'.RemoteVersion | Should Be 1.4.0
                $res.Result[-1]   | Should Be 'Package updated'
                (json_file).'1.2' | Should Be 1.2.4
                (json_file).'1.3' | Should Be 1.3.1
                (json_file).'1.4' | Should Be 1.4.0
            }

            It "does not update the package when remote version is not higher" {
                get_latest -Version 1.2.3

                $res = update

                $res.Updated      | Should Be $false
                $res.Streams.'1.2'.RemoteVersion       | Should Be 1.2.3
                $res.Streams.'1.3'.RemoteVersion       | Should Be 1.3.1
                $res.Streams.'1.4'.RemoteVersion       | Should Be 1.4-beta1
                (nuspec_file).package.metadata.version | Should Be 1.2.3
                (json_file).'1.2' | Should Be 1.2.3
                (json_file).'1.3' | Should Be 1.3.1
                (json_file).'1.4' | Should Be 1.4-beta1
            }

            It "throws an error when forcing update whithout specifying a stream" {
                get_latest -Version 1.2.3
                { update -Force -Include 1.2,1.4 } | Should Throw 'A single stream must be included when forcing package update'
            }

            It "updates the package when forced using choco fix notation" {
                get_latest -Version 1.2.3

                $res = update -Force -Include 1.2

                $d = (get-date).ToString('yyyyMMdd')
                $res.Updated      | Should Be $true
                $res.Result[-1]   | Should Be 'Package updated'
                $res.Result -match 'No new version found, but update is forced' | Should Not BeNullOrEmpty
                (nuspec_file).package.metadata.version | Should Be "1.2.3.$d"
                (json_file).'1.2' | Should Be "1.2.3.$d"
                (json_file).'1.3' | Should Be 1.3.1
                (json_file).'1.4' | Should Be 1.4-beta1
            }

            It "does not use choco fix notation if the package remote version is higher" {
                $res = update -Force -Include 1.2

                $res.Updated      | Should Be $true
                $res.Streams.'1.2'.RemoteVersion       | Should Be 1.2.4
                (nuspec_file).package.metadata.version | Should Be 1.2.4
                (json_file).'1.2' | Should Be 1.2.4
                (json_file).'1.3' | Should Be 1.3.1
                (json_file).'1.4' | Should Be 1.4-beta1
            }

            It "searches and replaces given file lines when updating" {
                function global:au_SearchReplace {
                    @{
                        'test_package_with_streams.nuspec' = @{
                            '(<releaseNotes>)(.*)(</releaseNotes>)' = "`$1test_package_with_streams.$($Latest.Version)`$3"
                        }
                    }
                }

                update

                $nu = (nuspec_file).package.metadata
                $nu.releaseNotes | Should Be 'test_package_with_streams.1.2.4'
                $nu.id           | Should Be 'test_package_with_streams'
                $nu.version      | Should Be 1.2.4
            }
        }

        Context 'Json file' {

            It 'loads a json file from the package directory' {
                { update } | Should Not Throw
            }

            It "uses version 0.0 if it can't find the json file in the current directory" {
                rm *.json
                update *> $null
                $global:Latest.NuspecVersion | Should Be '0.0'
            }

            It "uses version 0.0 on invalid json version" {
                $streams = json_file
                $streams.'1.2' = '{{PackageVersion}}'
                $streams | ConvertTo-Json | Set-Content "$TestDrive\test_package_with_streams\test_package_with_streams.json" -Encoding UTF8

                update -Include 1.2 *> $null

                $global:Latest.NuspecVersion | Should Be '0.0'
            }

            It "uses version 0.0 when a new stream is available" {
                get_latest -Version 1.5.0
                update *> $null
                $global:Latest.NuspecVersion | Should Be '0.0'
            }

            It "does not update the package when stream is ignored in json file" {
                $streams = json_file
                $streams.'1.2' = 'ignore'
                $streams | ConvertTo-Json | Set-Content "$TestDrive\test_package_with_streams\test_package_with_streams.json" -Encoding UTF8

                $res = update

                $res.Updated      | Should Be $false
            }
        }

        Context 'au_GetLatest' {

            It "throws if au_GetLatest doesn't return OrderedDictionary or HashTable for streams" {
                $return_value = @(1)
                function global:au_GetLatest { @{ Streams = $return_value } }
                { update } | Should Throw "doesn't return an OrderedDictionary or HashTable"
                $return_value = @()
                { update } | Should Throw "returned nothing"
            }

            It "supports properties defined outside streams" {
                get_latest -Version 1.4.0
                function au_BeforeUpdate { $global:Latest.Fake | Should Be 1 }
                update
            }

            It 'supports alphabetical streams' {
                $return_value = @{
                    dev    = @{ Version = '1.4.0' }
                    beta   = @{ Version = '1.3.1' }
                    stable = @{ Version = '1.2.4' }
                }
                function global:au_GetLatest { @{ Streams = $return_value } }

                $res = update

                $res.Updated       | Should Be $true
                $res.Result[-1]    | Should Be 'Package updated'
                (json_file).stable | Should Be 1.2.4
                (json_file).beta   | Should Be 1.3.1
                (json_file).dev    | Should Be 1.4.0
            }
        }

        Context 'Before and after update' {
            It 'calls au_BeforeUpdate if package is updated' {
                function au_BeforeUpdate { $global:Latest.test = 1 }
                update -Include 1.2
                $global:Latest.test | Should Be 1
            }

            It 'calls au_AfterUpdate if package is updated' {
                function au_AfterUpdate { $global:Latest.test = 1 }
                update -Include 1.2
                $global:Latest.test | Should Be 1
            }

            It 'doesnt call au_BeforeUpdate if package is not updated' {
                get_latest -Version 1.2.3
                function au_BeforeUpdate { $global:Latest.test = 1 }
                update -Include 1.2
                $global:Latest.test | Should BeNullOrEmpty
            }

            It 'does not change type of $Latest.Version when calling au_BeforeUpdate and au_AfterUpdate' {
                $return_value = @{
                    '1.4' = @{ Version = ConvertTo-AUVersion '1.4-beta1' }
                    '1.2' = @{ Version = '1.2.4' }
                    '1.3' = @{ Version = [version] '1.3.1' }
                }
                function global:au_GetLatest { @{ Streams = $return_value } }
                function checkLatest {
                    $return_latest = $return_value[$global:Latest.Stream]
                    $return_latest.Keys | % {
                        $global:Latest[$_] | Should BeOfType $return_latest[$_].GetType()
                        $global:Latest[$_] | Should BeExactly $return_latest[$_]
                    }
                }
                function au_BeforeUpdate { checkLatest }
                function au_BeforeUpdate { checkLatest }
                update
            }
        }
    }

    cd $saved_pwd
}
