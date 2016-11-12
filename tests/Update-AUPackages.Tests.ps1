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
        # Commented tests are invoked manually

        #It 'should execute Gist plugin' {
            #$Options.Report = @{
                #Type = 'text'
                #Path = "$au_root\report.txt"
            #}
            #$Options.RunInfo = @{
                #Path = "$au_root\runinfo.xml"
            #}
            #$Options.Gist = @{
                #Path = "$au_root\*.*"
            #}

            #$res = updateall -NoPlugins:$false -Options $Options
        #}

        #It 'should execute Mail plugin' {
            #$Options.Report = @{
                #Type = 'text'
                #Path = "$global:au_Root\report.txt"
            #}

            #$Options.Mail = @{
                #To          = 'test@localhost'
                #Server      = 'localhost'
                #UserName    = 'test_user'
                #Password    = 'test_pass'
                #Port        = 25
                #EnableSsl   = $true
                #Attachment  =  ("$global:au_Root\report.txt" -replace 'TestDrive:', $TestDrive)
                #SendAlways  = $true
            #}

            #if (!(ps papercut -ea ignore)) {
                #if (gcm papercut.exe -ea ignore) { start papercut.exe; sleep 5 }
                #else { Write-Warning 'Papercut is not installed - skipping test'; return }
            #}
            #rm $Env:APPDATA\Papercut\* -ea ignore
            #$res = updateall -NoPlugins:$false -Options $Options 6> $null

            #sleep 5
            #(ls $Env:APPDATA\Papercut\*).Count | Should Be 1
        #}

        It 'should execute Report plugin' {
            $Options.Report = @{
                Type = 'markdown'
                Path = "$global:au_Root\report.md"
                Params = @{ Github_UserRepo = 'majkinetor/chocolatey' }
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
                Parameter2 = 'p2'`
            }

            $res = updateall -NoPlugins:$false -Options $Options  6> $null

            Test-Path $Options.RunInfo.Path | Should Be $true
            $info = Import-Clixml $Options.RunInfo.Path
            $info.plugin_results.RunInfo -match 'Test.MyPassword' | Should Be $true
            $info.Options.Test.MyPassword | Should Be '*****' 
        }
    }

    # It 'should update package with checsum verification mode' {

    #     $choco_path = gcm choco.exe | % Source
    #     $choco_hash = Get-FileHash $choco_path -Algorithm SHA256 | % Hash
    #     gc $global:au_Root\test_package_1\update.ps1 | set content
    #     $content -replace '@\{.+\}', "@{ Version = '1.3'; ChecksumType32 = 'sha256'; Checksum32 = '$choco_hash'}" | set content
    #     $content -replace 'update', "update -ChecksumFor 32" | set content
    #     $content | sc $global:au_Root\test_package_1\update.ps1

    #     $res = updateall -Options $Options 6> $null
    #     $res.Count | Should Be $pkg_no
    #     $res[0].Updated | Should Be $true
    # }

    It 'should limit update time' {
        gc $global:au_Root\test_package_1\update.ps1 | set content
        $content -replace 'update', "sleep 10; update" | set content
        $content | sc $global:au_Root\test_package_1\update.ps1
        $Options.UpdateTimeout = 5

        $res = updateall -Options $Options 3>$null 6> $null
        $res[0].Error -eq "Job termintated due to the 5s UpdateTimeout" | Should Be $true
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

