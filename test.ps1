param(
    [switch]$Chocolatey,

    [switch]$Pester,
    [string]$Tag,
    [switch]$CodeCoverage
)

if (!$Chocolatey -and !$Pester) { $Chocolatey = $Pester = $true }

$build_dir = Get-Item $PSScriptRoot/_build/*

if ($Chocolatey) {
    Write-Host "`n==| Running Chocolatey tests"

    . $PSScriptRoot/AU/Public/Test-Package.ps1
    Test-Package $build_dir
}

if ($Pester) {
    Write-Host "`n==| Running Pester tests"

    $testResultsFile = "$build_dir/TestResults.xml"
    if ($CodeCoverage) {
        $files = @(Get-ChildItem $PSScriptRoot/AU/* -Filter *.ps1 -Recurse | ForEach-Object FullName)
        Invoke-Pester -Tag $Tag -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru -CodeCoverage $files
    } else {
        Invoke-Pester -Tag $Tag -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
    }
}
