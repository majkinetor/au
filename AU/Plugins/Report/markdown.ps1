. $PSScriptRoot\markdown_funcs.ps1

$OFS="`r`n"

$icon_ok = 'https://cdn0.iconfinder.com/data/icons/shift-free/32/Complete_Symbol-128.png'
$icon_er = 'https://cdn0.iconfinder.com/data/icons/shift-free/32/Error-128.png'

$errors_word = if ($Info.error_count.total -eq 1) {'error'} else {'errors' }
if ($Info.error_count.total) {
    "<img src='$icon_er' width='48'> **LAST RUN HAD $($Info.error_count.total) [$errors_word](#errors) !!!**" }
else {
    "<img src='$icon_ok' width='48'> Last run was OK"
}

""
md_fix_newline $Info.stats

if ($Info.pushed) {
    md_title Pushed
    md_table $Info.result.pushed -Columns 'Name', 'Updated', 'Pushed', 'RemoteVersion', 'NuspecVersion'
}

if ($Info.error_count.total) {
    md_title Errors
    md_table $Info.result.errors -Columns 'Name', 'NuspecVersion', 'Error'
    $Info.result.errors | % {
        md_title $_.Name -Level 3
        md_code "$($_.Error)"
    }
}

if ($Info.result.ok) {
    md_title OK
    md_table $Info.result.ok -Columns 'Name', 'Updated', 'Pushed', 'RemoteVersion', 'NuspecVersion'
    $Info.result.ok | % {
        md_title $_.Name -Level 3
        md_code $_.Result
    }
}
