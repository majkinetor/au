$build_dir = gi $PSScriptRoot/_build/*

. $PSScriptRoot/AU/Public/Test-Package.ps1
Test-Package $build_dir

$testResultsFile = "$build_dir/TestResults.xml"
$res = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
$res
