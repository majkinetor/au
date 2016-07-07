# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 07-Jul-2016.

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

        # Hashtable with options
        # Available options:
        #  Threads - Number of background jobs to use, by default 10
        #  Timeout - WebRequest timeout in seconds, by default 100
        #  Push    - Set to true to push updated packages to chocolatey repository
        #  Mail    - Hashtable with mail notification options: To, Server, UserName, Password, Port, EnableSsl
        #  Script  - Specify script to be executed at the start and after update. Script accepts two arguments:
        #               $PHASE  - can be 'start' or 'end'
        #               $ARG    - in start phase it is list of packages to be updated;
        #                         in end phase it is info object that contains various info about previous run;
        [HashTable] $Options=@{}
    )

    $cd = $pwd
    $startTime = Get-Date
    Write-Host 'Updating all automatic packages:' $startTime

    if (!$Options.Threads) { $Options.Threads = 10}
    if (!$Options.Timeout) { $Options.Timeout = 100 }
    if (!$Options.Push)    { $Options.Push = $false}

    $threads    = New-Object object[] $Options.Threads
    $result     = @()
    $script_err = 0

    $aup = Get-AUPackages $Name
    $j = 0

    if ($Options.Script) { try { & $Options.Script 'START' $aup | Write-Host } catch { Write-Error $_; $script_err += 1 } }
    Remove-Job * -force
    while( $true ) {

        # Check for complted jobs
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
                $i.Updated = $false
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

    $info = get-info
    if ($Options.Script) { try { & $Options.Script 'END' $info | Write-Host } catch { Write-Error $_; $script_err += 1 } }

    show-stats

    # Send email
    if ($error_no -and $Options.Mail) {
        $body = "$error_no errors during update`n`n"
        $body +=  $errors | % {
            $s = "`nPackage: " + $_.PackageName + "`n"
            $s += $_.Error | out-string
            $s
        }
        try {
            send-mail $Options.Mail $body -ea Stop
            Write-Host ("Mail with errors sent to " + $Options.Mail.To)
        } catch { Write-Error $_ }
    }

    $result
}

function get-info {
    $errors   = $result | ? { $_.Error.Length }
    $info = [PSCustomObject]@{
        errors = $errors
        error_count = [PSCustomObject]@{
            update  = $errors | ? !Updated | measure | % count
            push    = $errors | ? {$_.Updated -and !$_.Pushed} | measure | % count
            total   = $errors | measure | % count
        }
        minutes  = ((Get-Date) - $startTime).TotalMinutes.ToString('#.##')
        packages = $aup
        pushed   = $result | ? Pushed | measure | % count
        updated  = $result | ? Updated | measure | % count
        result   = $result
    }
    return $info
}

function show-stats {
    Write-Host ( "`nFinished {0} packages after {1} minutes." -f $info.packages.length, $info.minutes )
    Write-Host ( "{0} packages updated and {1} pushed." -f $info.updated, $info.pushed )
    Write-Host ( "{0} total errors; {1} update, {0} push" -f $info.error_count.total, $info.error_count.update, $info.error_count.push )
    if ($Options.Script) { Write-Host "There are $script_err user script errors" }
}

function send-mail($Mail, $Body) {
    $from = "Update-AUPackages@{0}.{1}" -f $Env:UserName, $Env:ComputerName
    $msg  = New-Object System.Net.Mail.MailMessage $from, $Mail.To
    $msg.Subject    = "$error_no errors during update"
    $msg.IsBodyHTML = $true
    $msg.Body       = "<body><pre>$Body</pre></body>"

    $result | Export-CliXML "$Env:TEMP\au_result.xml"
    $attachment = new-object Net.Mail.Attachment( "$Env:TEMP\au_result.xml" )
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
