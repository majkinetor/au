remove-module AU -ea ignore
import-module $PSScriptRoot\..\AU

Describe 'Update-AUPackages' -Tag updateall {
    $saved_pwd = $pwd

    function global:nuspec_file() { [xml](gc $PSScriptRoot/test_package/test_package.nuspec) }
    $pkg_no = 3

    BeforeEach {
        $global:au_Root      = "TestDrive:\packages"
        $global:au_NoPlugins = $true

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
            "import-module '$module_path' -Force", (gc $path\update.ps1 -ea ignore) | sc $path\update.ps1
        }

        $Options = [ordered]@{}
    }

    Context 'Plugins' {
        It 'should execute Mail plugin' {
            $Options.Report = @{
                Type = 'text'
                Path = "$global:au_Root\report.txt"
            }

            $Options.Mail = @{
                To          = 'test@localhost'
                Server      = 'localhost'
                UserName    = 'test_user'
                Password    = 'test_pass'
                Port        = 25
                EnableSsl   = $true
                Attachment  =  ("$global:au_Root\report.txt" -replace 'TestDrive:', $TestDrive)
                SendAlways  = $true
            }

            if (!(ps papercut -ea ignore)) {
                if (gcm papercut.exe -ea ignore) { start papercut.exe; sleep 5 }
                else { Write-Warning 'Papercut is not installed - skipping test'; return }
            }
            rm $Env:APPDATA\Papercut\* -ea ignore
            $res = updateall -NoPlugins:$false -Options $Options

            sleep 5
            (ls $Env:APPDATA\Papercut\*).Count | Should Be 1
        }

        It 'should execute Report plugin' {
            $Options.Report = @{
                Type = 'text'
                Path = "$global:au_Root\report.txt"
            }

            $res = updateall -NoPlugins:$false -Options $Options  6> $null

            Test-Path $Options.Report.Path | Should Be $true

            $report = gc $Options.Report.Path 
            ($report -match "test_package_[1-3]").Count | Should Be 9
        }

    It 'should execute RunInfo plugin' {
        $Options.RunInfo = @{
            Path    = "$global:au_Root\update_info.xml"
            Exclude = 'password'
        }
        $Options.Test = @{
            MyPassword = 'password'
            Parameter2 = 'p2'
        }

        $res = updateall -NoPlugins:$false -Options $Options  6> $null

        Test-Path $Options.RunInfo.Path | Should Be $true
        $info = Import-Clixml $Options.RunInfo.Path
        $info.plugin_results.RunInfo -match 'Test.MyPassword' | Should Be $true
        $info.Options.Test.MyPassword | Should Be '*****' 
    }
    }

   

    It 'should update all packages when forced' {
        $Options.Force = $true

        $res = updateall -Options $Options 6> $null

        lsau | measure | % Count | Should Be $pkg_no
        $res.Count | Should Be $pkg_no
        ($res.Result -match 'update is forced').Count | Should Be $pkg_no
        ($res | ? Updated).Count | Should Be $pkg_no
    }

    It 'should update no packages when none is newer' {
        $res = updateall 6> $null

        lsau | measure | % Count | Should Be $pkg_no
        $res.Count | Should Be $pkg_no
        ($res.Result -match 'No new version found').Count | Should Be $pkg_no
        ($res | ? Updated).Count | Should Be 0
    }

    $saved_pwd = $pwd
}

