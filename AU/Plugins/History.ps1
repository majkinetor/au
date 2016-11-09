# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 09-Nov-2016.

param(
    $Info,
    $Lines=30,
    $Github_UserRepo = 'chocolatey/chocolatey-coreteampackages',
    $Path = "UpdateHistory.md"
)

Write-Host "Saving history to $Path"

$res=[ordered]@{}
$log = git --no-pager log -q --grep '^AU: ' --date iso | Out-String
$all_commits = $log | sls 'commit(.|\n)+?\s+AU:.+' -AllMatches
foreach ($commit in $all_commits.Matches.Value) {
    $commit = $commit -split '\n'

    $id   = $commit[0].Replace('commit','').Trim()
    $date = $commit[2].Replace('Date:','').Trim()
    $date = ([datetime]$date).Date.ToString("yyyy-MM-dd")

    $packages = $commit[-1] -replace '^\s+AU:.+?(-|:) |\[skip ci\]'
    $packages = $packages.Trim() -split ' ' | % {"[$_](https://github.com/$Github_UserRepo/commit/{0})" -f $id.Substring(0,6)}
    if (!$res.Contains($date)) { $res.$date=@() }
    $res.$date += $packages -split ' '
}

$res = $res | select -First $Lines

$history = "# Update History`n"
foreach ($kv in $res.GetEnumerator()) { $history += "`n{0,-25} {1}`n" -f "**$($kv.Key)**", "$($kv.Value -join ' &ndash; ')" }
$history | Out-File $Path
