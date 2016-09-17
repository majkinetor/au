param(
    [switch]$Chocolatey,

    [switch]$Pester,
    [string]$Tag
)

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
    Invoke-Pester -Tag $Tag -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
}
