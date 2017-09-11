#requires -version 3

$paths = "Private", "Public"
foreach ($path in $paths) {
    Get-ChildItem $PSScriptRoot\$path\*.ps1 | foreach { . $_ }
}
