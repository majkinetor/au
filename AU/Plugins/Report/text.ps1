$UserMessage = $Params.UserMessage
$Title       = if ($Params.Title) { $Params.Title } else {  'Update-AUPackages' }

#==============================================================================

function title($txt) { "`r`n{0}`r`n{1}`r`n" -f $txt,('-'*$txt.Length) }
function indent($txt, $level=4) { $txt -split "`n" | ForEach-Object { ' '*$level + $_ } }

$now         = $Info.startTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
$au_version  = Get-Module au -ListAvailable | ForEach-Object Version | Select-Object -First 1 | ForEach-Object { "$_" }
$package_no  = $Info.result.all.Length

"{0,-15}{1}" -f 'Title:', $Title
"{0,-15}{1}" -f 'Time:', $now
"{0,-15}{1}" -f 'AU version:', $au_version
"{0,-15}{1}" -f 'AU packages:', $package_no

$errors_word = if ($Info.error_count.total -eq 1) {'error'} else {'errors' }
if ($Info.error_count.total) {
    "LAST RUN HAD $($Info.error_count.total) $errors_word !!!" }
else {
    "Last run was OK"
}

""; $Info.stats

""; $UserMessage; ""

if ($Info.pushed) {
    title Pushed
    $Info.result.pushed | Select-Object 'Name', 'Updated', 'Pushed', 'RemoteVersion', 'NuspecVersion' | Format-Table | Out-String | Set-Variable r
    indent $r 2

    $Info.result.pushed | ForEach-Object { $_.Name; indent $_.Result; "" }
}

if ($Info.error_count.total) {
    title Errors
    $Info.result.errors | Select-Object 'Name', 'NuspecVersion', 'Error' | Format-Table | Out-String | Set-Variable r
    indent $r 2

    $Info.result.errors | ForEach-Object { $_.Name; indent $_.Error; "" }
}


if ($Info.result.ignored) {
    title Ignored
    $Info.result.ignored | Format-Table | Select-Object 'Name', 'NuspecVersion', 'IgnoreMessage' | Format-Table | Out-String | Set-Variable r
    indent $r 2
}

$ok = $Info.result.ok | Where-Object { !$_.Pushed }
if ($ok) {
    title OK
    $ok | Select-Object 'Name', 'Updated', 'RemoteVersion', 'NuspecVersion' | Format-Table | Out-String | Set-Variable r
    indent $r 2

    $ok | ForEach-Object { $_.Name; indent $_.Result; "" }
}

