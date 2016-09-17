#requires -version 3

$paths = "Private", "Public"
foreach ($path in $paths) {
    ls $PSScriptRoot\$path\*.ps1 | % { . $_ }
}
