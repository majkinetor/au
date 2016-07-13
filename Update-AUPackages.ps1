# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 13-Jul-2016.

<#
.SYNOPSIS
    Update all automatic package in the current directory

.DESCRIPTION
    Function Update-AUPackages will iterate over update.ps1 scripts and execute each. If it detects
    that package is updated it will cpack it and push it. For push to work, specify your API key in the
    file 'api_key' in the script's directory.

.EXAMPLE
    Update-AUPackages p* @{ Threads = 5; Timeout = 10 }

    Update all automatic packages in the current directory that start with letter 'p' using 5 threads
    and web timeout of 10 seconds.
#>
function Update-AUPackages {
    [CmdletBinding()]
    param(
        # Filter package names. Supports globs.
        [string] $Name,

        <#
        Hashtable with options:
          Threads     - Number of background jobs to use, by default 10
          Timeout     - WebRequest timeout in seconds, by default 100
          Push        - Set to true to push updated packages to chocolatey repository
          Mail        - Hashtable with mail notification options: To, Server, UserName, Password, Port, EnableSsl
          Script      - Specify script to be executed at the start and after the update. Script accepts two arguments:
                          $PHASE  - can be 'start' or 'end'
                          $ARG    - in start phase it is the list of packages to be updated;
                                    in end phase it is the info object that contains information about the previous run;
        #>
        [HashTable] $Options=@{}
    )

    function Load-NuspecFile() {
        $nu = New-Object xml
        $nu.psbase.PreserveWhitespace = $true
        $nu.Load($nuspecFile)
        $nu
    }

    $cd = $pwd
    $startTime = Get-Date

    if (!$Options.Threads) { $Options.Threads = 10}
    if (!$Options.Timeout) { $Options.Timeout = 100 }
    if (!$Options.Push)    { $Options.Push = $false}

    $threads    = New-Object object[] $Options.Threads
    $result     = @()
    $script_err = 0

    $aup = Get-AUPackages $Name
    $j = 0

    Write-Host 'Updating' $aup.Length  'automatic packages at' $startTime

    if ($Options.Script) { try { & $Options.Script 'START' $aup | Write-Host } catch { Write-Error $_; $script_err += 1 } }
    Remove-Job * -force
    while( $true ) {

        # Check for completed jobs
        Get-Job | ? state -ne 'Running' | % {
            $job = $_

            if ( 'Failed', 'Completed' -notcontains $job.State) { 
                Write-Host "Invalid job state for $($job.Name): " + $job.State 
            }
            else {
                Write-Verbose ($job.State + ' ' + $job.Name)
                $i = [ordered]@{PackageName=''; Updated=''; Pushed=''; RemoteVersion=''; NuspecVersion=''; Message=''; Result=''; Error=@()}
                $i.PackageName = $job.Name

                $i.Result  = Receive-Job $_ -ErrorAction SilentlyContinue -ErrorVariable err
                $i.Error   = $err
                $i.Updated = $i.Pushed = $false
                if ($i.Result)
                {
                    $i.Updated       = $i.Result -contains 'Package updated'
                    $i.RemoteVersion = ($i.Result -match '^remote version: .+$').Substring(16)
                    $i.NuspecVersion = ($i.Result -match '^nuspec version: .+$').Substring(16)
                    $i.Message       = $i.PackageName + ' '
                    $i.Message      += if ($i.Updated) { 'is updated to ' + $i.RemoteVersion } else { 'has no updates' }

                    if ($i.Updated -and $Options.Push) {
                        $i.Pushed = ($i.Result -like 'Failed to process request*').Length -eq 0
                        if (!$i.Pushed) {
                            $i.Message += ' but push failed!'
                            $i.Error += ($i.Result | sls "Attempting to push" -Context 0,10).ToString()
                        } else { $i.Message += ' and pushed' }
                    }

                    Write-Host '  ' $i.Message
                }

                if ($i.Error) {
                    #When packages ./update.ps1 fails no nuspec version is available in the output
                    $nuspecFile = "$pwd\{0}\{0}.nuspec" -f $i.PackageName
                    $i.NuspecVersion = (Load-NuspecFile($nuspecFile)).package.metadata.version

                    Write-Host "   $($i.PackageName) ERROR:"
                    $i.Error[0].ToString() -split "`n" | % { Write-Host (' '*5 + $_) }
                }

                $result += [pscustomobject]$i
            }
            Remove-Job $job
        }

        # Check if all pacakges are done
        $job_count = Get-Job | measure | % count
        if ($result.length -eq $aup.length) { break }

        # Just sleep a bit and repeat if all threads are buisy
        if (($job_count -eq $Options.Threads) -or ($j -eq $aup.length)) { sleep 1; continue }

        # Start a new thread
        $package_path = $aup[$j++]
        $package_name = Split-Path $package_path -Leaf
        Write-Verbose "Starting $package_name"
        Start-Job -Name $package_name {
            cd $using:package_path

            $global:au_timeout = $using:Options.Timeout
            $res = ./update.ps1

            $updated = ![string]::IsNullOrEmpty($res) -and ($res[-1] -eq 'Package updated')
            if ($updated -and $using:Options.Push) {
                import-module au
                $res += Push-Package
            }

            $res
        } | out-null
    }
    $result = $result | sort PackageName

    $info = get-info
    if ($Options.Script) { try { & $Options.Script 'END' $info | Write-Host } catch { Write-Error $_; $script_err += 1 } }

    "", $info.stats | Write-Host
    send-notification

    $result
}

function send-notification() {
    if (!($info.error_count.total -and $Options.Mail)) { return }

    $body = "$($info.error_count.total) errors during update`n"
    $body += "Attachment contains complete output of the run, you can load it using Import-CliXML cmdlet.`n`n"
    $body += $info.error_info

    try {
        send-mail $Options.Mail $body -ea Stop
        Write-Host ("Mail with errors sent to " + $Options.Mail.To)
    } catch { Write-Error $_ }
}

function get-info {
    $errors = $result | ? { $_.Error.Length }
    $info = [PSCustomObject]@{
        result = [PSCustomObject]@{
            all     = $result
            errors  = $errors
            ok      = $result | ? { !$_.Error.Length }
            pushed  = $result | ? Pushed
            updated = $result | ? Updated
        }

        error_count = [PSCustomObject]@{
            update  = $errors | ? {!$_.Updated} | measure | % count
            push    = $errors | ? {$_.Updated -and !$_.Pushed} | measure | % count
            total   = $errors | measure | % count
        }
        error_info  = ''

        packages  = $aup
        startTime = $startTime
        minutes   = ((Get-Date) - $startTime).TotalMinutes.ToString('#.##')
        pushed    = $result | ? Pushed  | measure | % count
        updated   = $result | ? Updated | measure | % count
        stats     = ''
        options   = $Options
    }
    $info.stats = get-stats
    $info.error_info = $errors | % {
        $s = "`nPackage: " + $_.PackageName + "`n"
        $_.Error | out-string
    }

    $info
}

function get-stats {
    "Finished {0} packages after {1} minutes." -f $info.packages.all.length, $info.minutes
    "{0} packages updated and {1} pushed." -f $info.updated, $info.pushed
    "{0} total errors - {1} update, {2} push." -f $info.error_count.total, $info.error_count.update, $info.error_count.push
    if ($Options.Script) { "$script_err user script errors." }
}

function send-mail($Mail, $Body) {
    $from = "Update-AUPackages@{0}.{1}" -f $Env:UserName, $Env:ComputerName
    $msg  = New-Object System.Net.Mail.MailMessage $from, $Mail.To
    $msg.Subject    = "$($info.error_count.total) errors during update"
    $msg.IsBodyHTML = $true
    $msg.Body       = "<body><pre>$Body</pre></body>"

    $info | Export-CliXML "$Env:TEMP\au_info.xml"
    $attachment = new-object Net.Mail.Attachment( "$Env:TEMP\au_info.xml" )
    $msg.Attachments.Add($attachment)

    $smtp = new-object Net.Mail.SmtpClient($Mail.Server)
    if ($Mail.UserName) {
        $smtp.Credentials = new-object System.Net.NetworkCredential($Mail.UserName, $Mail.Password)
    }
    if ($Mail.Port) { $smtp.port = $Mail.Port }
    $smtp.EnableSsl = $Mail.EnableSsl
    $smtp.Send($msg)
}

Set-Alias updateall Update-AuPackages
