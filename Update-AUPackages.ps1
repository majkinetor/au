function Update-AUPackages($name, [switch]$Push, [hashtable]$Options) {
    $cd = $pwd
    Write-Host 'Updating all automatic packages'

    $result = @()
    $a = Get-AUPackages $name
    $a | % {
        $i = [ordered]@{PackageName=''; Updated=''; RemoteVersion=''; NuspecVersion=''; Message=''; Result=''; PushResult=''; Error=$null}

        Set-Location $_
        $i.PackageName = Split-Path $_ -Leaf
        try {
            $i.Result        = .\update.ps1
            $i.Updated       = $i.Result[-1] -eq 'Package updated'
            $i.RemoteVersion = ($i.Result -match '^remote version: .+$').Substring(16)
            $i.NuspecVersion = ($i.Result -match '^nuspec version: .+$').Substring(16)

            if ($i.Updated -and $Push) { i.PushResult = push-package }

            if ($i.Updated) {
                $i.Message = '{0} is updated to {1}' -f $i.PackageName, $i.RemoteVersion
                if ($Push) { $i.Message += ' and pushed' }
            }
            else { $i.Message = $i.PackageName + ' has no updates' }

        } catch {
            $i.Error = $_
            $i.Message = $i.PackageName + " had errors during update"
            $i.Error -split '\n' | % { $i.Message += "`n    $_" }
        }
        Write-Host "  $($i.Message)"
        $result += [pscustomobject]$i
    }
    Set-Location $cd

    Write-Host ""
    Write-Host "Automatic packages processed: $($result.Length)"

    $errors = $result | ? {$_.Error -ne $null}
    $total_errors = ($errors | measure).Count
    Write-Host "Total errors: $total_errors"

    if ($total_errors -gt 0) {
        if ($Options.Mail) {
            Send-Mail $Options.Mail ($errors | out-string)
            Write-Host ("Mail with errors sent to " + $Options.Mail.To)
        }
    }
    $result
}

Set-Alias updateall Update-AuPackages
