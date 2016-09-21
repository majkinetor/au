function title($txt) { "`r`n{0}`r`n{1}`r`n" -f $txt,('-'*$txt.Length) }
function indent($txt, $level=4) { $txt -split "`n" | % { ' '*$level + $_ } }

$now             = $Info.startTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
$au_version      = gmo au -ListAvailable | % Version | select -First 1 | % { "$_" }

"{0,15}{1}" -f 'Time:', $now
"{0,15}{1}" -f 'AU version:', $au_version
"{0,15}{1}" -f 'AU packages:', $package_no

$errors_word = if ($Info.error_count.total -eq 1) {'error'} else {'errors' }
if ($Info.error_count.total) {
    "LAST RUN HAD $($Info.error_count.total) $errors_word !!!" }
else {
    "Last run was OK"
}

""; $Info.stats


if ($Info.pushed) {
    title Pushed
    $Info.result.pushed | select 'Name', 'Updated', 'Pushed', 'RemoteVersion', 'NuspecVersion' | ft | Out-String | set r
    indent $r 2

    $ok | % { $_.Name; indent $_.Result; "" }
}

if ($Info.error_count.total) {
    title Errors
    $Info.result.errors | select 'Name', 'NuspecVersion', 'Error' | ft | Out-String | set r
    indent $r 2

    $Info.result.errors | % { $_.Name; ident $_.Error; "" }
}

$ok = $Info.result.ok | ? { !$_.Pushed }
if ($ok) {
    title OK
    $ok | select 'Name', 'Updated', 'RemoteVersion', 'NuspecVersion' | ft | Out-String | set r
    indent $r 2

    $ok | % { $_.Name; indent $_.Result; "" }
}

