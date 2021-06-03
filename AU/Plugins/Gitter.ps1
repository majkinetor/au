# Author: Kim Nordmo <kim.nordmo@gmail.com>
# Last Change: 2018-06-13
<#
.SYNOPSIS
  Publishes the package update status to gitter.

.PARAMETER WebHookUrl
  This is the cusotm webhook url created through gitter integrations.

.PARAMETER MessageFormat
  The format of the message that is meant to be published on gitter.
  {0} = The total number of automated packages.
  {1} = The number of updated packages,
  {2} = The number of published packages.
  {3} = The number of failed packages.
  {4} = The url to the github gist.
#>
param(
  $Info,
  [string]$WebHookUrl,
  [string]$MessageFormat = "[Update Status:{0} packages.`n  {1} updated, {2} Published, {3} Failed]({4})"
)

if (!$WebHookUrl) { return } # If we don't have a webhookurl we can't push status messages, so ignore.

$updatedPackages   = @($Info.result.updated).Count
$publishedPackages = @($Info.result.pushed).Count
$failedPackages    = $Info.error_count.total
$gistUrl           = $Info.plugin_results.Gist -split '\n' | Select-Object -Last 1
$packageCount      = $Info.result.all.Length

$gitterMessage     = ($MessageFormat -f $packageCount, $updatedPackages, $publishedPackages, $failedPackages, $gistUrl)

$arguments = @{
  Body             = if ($failedPackages -gt 0) { "message=$gitterMessage&level=error" } else { "message=$gitterMessage" }
  UseBasicParsing  = $true
  Uri              = $WebHookUrl
  ContentType      = 'application/x-www-form-urlencoded'
  Method           = 'Post'
}

"Submitting message to gitter"
Invoke-RestMethod @arguments
"Message submitted to gitter"