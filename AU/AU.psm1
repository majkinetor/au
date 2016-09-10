#requires -version 3

#All private and public functions are available when loading module via psm1.
#Everything is set correctly when module is loaded via psd1.
ls -Recurse $PSScriptRoot\*.ps1 | % { . $_ }
