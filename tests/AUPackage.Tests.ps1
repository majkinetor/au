remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'AUPackage' -Tag aupackage {
    InModuleScope AU {
        It 'throws an error when intanciating without a path' {
            { [AUPackage]::new('') } | Should Throw 'empty'
        }

        It 'throws an error when intanciating without a hashtable' {
            { [AUPackage]::new([hashtable] $null) } | Should Throw 'empty'
        }

        It 'can serialize and deserialize' {
            $expected = @{
                Path = 'path'
                Name = 'name'
                Updated = $true
                Pushed = $true
                RemoteVersion = '1.2.3'
                NuspecVersion = '0.1.2'
                Result = 'result1,result2,result3' -split ','
                Error = 'error'
                NuspecPath = 'nuspecPath'
                Ignored = $true
                IgnoreMessage = 'ignoreMessage'
                StreamsPath = 'streamsPath'
                Streams = [PSCustomObject] @{
                    '0.1' = @{ 
                        NuspecVersion = '0.1.2'
                        Path = 'path'
                        Name = 'name'
                        Updated = $true
                        RemoteVersion = '1.2.3'
                    }
                    '0.2' = @{ 
                        NuspecVersion = '0.2.2'
                        Path = 'path'
                        Name = 'name'
                        Updated = $true
                        RemoteVersion = '1.2.3'
                    }
                }
            }

            $package = [AUPackage]::new($expected)
            $actual = $package.Serialize()

            $expected.Keys | Where-Object { $_ -ne 'Streams' } | ForEach-Object {
                $actual.$_ | Should Be $expected.$_
            }
            $expected.Streams.psobject.Properties | ForEach-Object {
                $actual.Streams.$_ | Should Be $expected.Streams.$_
            }
        }
    }
}
