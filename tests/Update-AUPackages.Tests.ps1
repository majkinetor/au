remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Update-AUPackages' {

    function global:nuspec_file() { [xml](gc $PSScriptRoot/test_package/test_package.nuspec) }
    $pkg_no = 3

    BeforeEach {
        $global:au_root = "TestDrive:\packages"

        rm -Recurse $global:au_root -ea ignore
        foreach ( $i in 1..$pkg_no ) {
            $name = "test_package_$i"
            $path = "$au_root\$name"

            cp -Recurse -Force $PSScriptRoot\test_package $path
            $nu = nuspec_file
            $nu.package.metadata.id = $name
            rm "$au_root\$name\*.nuspec"
            $nu.OuterXml | sc "$path\$name.nuspec"

            $module_path = Resolve-Path $PSScriptRoot\..\AU
            "import-module '$module_path'", (gc $path\update.ps1 -ea ignore) | sc $path\update.ps1
        }

        $Options = @{}
    }

    It 'should update all packages when forced' {
        $Options.Force = $true
        $res = updateall -Options $Options 6> $null
        $res.Count | Should Be $pkg_no
        ($res.Result -match 'update is forced').Count | Should Be $pkg_no
        ($res | ? Updated).Count | Should Be $pkg_no
    }

    It 'should update no packages when none is newer' {
        $res = updateall 6> $null
        $res.Count | Should Be $pkg_no
        ($res.Result -match 'No new version found').Count | Should Be $pkg_no
        ($res | ? Updated).Count | Should Be 0
    }

}
