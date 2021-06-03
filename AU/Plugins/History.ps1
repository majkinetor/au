# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 09-Dec-2016.

<#
.SYNOPSIS
    Create update history as markdown report

.DESCRIPTION
    Shows one date per line and all of the packages pushed to the Chocolatey community
    repository during that day. First letter of the package name links to report
    (produced by the Report plugin), the rest links to the actuall commit (produced by the Git plugin).
#>
param(
    $Info,

    #Number of dates to show in the report
    $Lines=30,

    #Github user repository, used to create commit links
    $Github_UserRepo = 'chocolatey/chocolatey-coreteampackages',

    #File path where to save the markdown report
    $Path = "Update-History.md"
)

Write-Host "Saving history to $Path"

$res=[System.Collections.Specialized.OrderedDictionary]@{}
$log = git --no-pager log -q --grep '^AU: ' --date iso --all | Out-String
$all_commits = $log | Select-String 'commit(.|\n)+?(?=\ncommit )' -AllMatches
foreach ($commit in $all_commits.Matches.Value) {
    $commit = $commit -split '\n'

    $id       = $commit[0].Replace('commit','').Trim().Substring(0,7)
    $date     = $commit[2].Replace('Date:','').Trim()
    $date     = ([datetime]$date).Date.ToString("yyyy-MM-dd")
    $report   = $commit[5].Replace('[skip ci]','').Trim()
    [array] $packages = ($commit[4] -replace '^\s+AU:.+?(-|:) |\[skip ci\]').Trim().ToLower()

    $packages_md = $packages -split ' ' | ForEach-Object {
        $first = $_.Substring(0,1).ToUpper(); $rest  = $_.Substring(1)
        if ($report) {
            "[$first]($report)[$rest](https://github.com/$Github_UserRepo/commit/$id)"
        } else {
            "[$_](https://github.com/$Github_UserRepo/commit/$id)"
        }
    }

    if (!$res.Contains($date)) { $res.$date=@() }
    $res.$date += $packages_md
}

$res = $res.Keys | Select-Object -First $Lines | ForEach-Object { $r=[System.Collections.Specialized.OrderedDictionary]@{} } { $r[$_] = $res[$_] } {$r}

$history = @"
# Update History

Showing maximum $Lines dates.
Click on the first letter of the package name to see its report and on the remaining letters to see its git commit.

---

"@
foreach ($kv in $res.GetEnumerator()) { $history += "`n{0} ({2}) {1}`n" -f "**$($kv.Key)**", "$($kv.Value -join ' &ndash; ')", $kv.Value.Length }
$history | Out-File $Path
