#requires -version 3

ls -Recurse $PSScriptRoot\*.ps1 | % { . $_ }
