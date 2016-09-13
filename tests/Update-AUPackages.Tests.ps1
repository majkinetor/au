remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Update-AUPackages' {

   function global:nuspec_file() { [xml](gc $PSScriptRoot/test_package/test_package.nuspec) }

    BeforeEach {
        $global:au_root = "TestDrive:\packages"

        rm -Recurse $global:au_root -ea ignore
        foreach ( $i in 1..3 ) {
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
        $res = updateall -Options $Options
        $res.Count | Should Be 3
    }

}
