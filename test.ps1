param( [switch]$Chocolatey, [switch]$Pester )

if (!$Chocolatey -and !$Pester) { $Chocolatey = $Pester = $true }

$build_dir = gi $PSScriptRoot/_build/*

if ($Chocolatey) {
    Write-Host "`n==| Running Chocolatey tests"

    . $PSScriptRoot/AU/Public/Test-Package.ps1
    Test-Package $build_dir
}

if ($Pester) {
    Write-Host "`n==| Running Pester tests"

    $testResultsFile = "$build_dir/TestResults.xml"
    $res = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
    $res
}
