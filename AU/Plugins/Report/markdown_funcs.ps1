function md_fix_newline($Text) {
    $Text -replace "\.`n", "\.`n  "
}

function md_title($Title, $Level=2 ) {
    ""
    "#"*$Level + ' ' + $Title
    ""
}

function md_code($Text) {
    "`n" + '```'
    ($Text -join "`n").Trim()
    '```' + "`n"
}

function md_table($result, $Columns, $MaxErrorLength=150) {
    if (!$Columns) { $Columns = 'Name', 'Updated', 'Pushed', 'RemoteVersion', 'NuspecVersion', 'Error' }
    $res = '|' + ($Columns -join '|') + "|`r`n"
    $res += ((1..$Columns.Length | % { '|---' }) -join '') + "|`r`n"

    $result | % {
        $o = $_ | select `
                @{ N='Name'
                   E={'[{0}](https://chocolatey.org/packages/{0}/{1})' -f $_.Name, $(if ($_.Updated) { $_.RemoteVersion } else {$_.NuspecVersion })}
                },
                @{ N='Updated'
                    E={
                        $r  = "[{0}](#{1})" -f $_.Updated, $_.Name.ToLower()
                        $r += if ($_.Updated) { ' &#x1F538;' }
                        $r
                    }
                },
                'Pushed', 'RemoteVersion', 'NuspecVersion',
                @{ N='Error'
                   E={
                        $err = ("$($_.Error)" -replace "`r?`n", '; ').Trim()
                        if ($err) {
                            if ($err.Length -gt $MaxErrorLength) { $err = $err.Substring(0,$MaxErrorLength) + ' ...' }
                            "[{0}](#{1})" -f $err, $_.Name.ToLower()
                        }
                    }
                }

        $res += ((1..$Columns.Length | % { $col = $Columns[$_-1]; '|' + $o.$col }) -join '') + "|`r`n"
    }

    $res
}
