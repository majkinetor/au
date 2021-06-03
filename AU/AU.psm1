#requires -version 3

$paths = "Private", "Public"
foreach ($path in $paths) {
    Get-ChildItem ([System.IO.Path]::Combine($PSScriptRoot, $path, '*.ps1')) | ForEach-Object { . $_.FullName }
}
