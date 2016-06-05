# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 05-Jun-2016.

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
        [HashTable] $Options=@{}
    )

    $cd = $pwd
    $now = Get-Date
    Write-Host 'Updating all automatic packages:' $now

    if (!$Options.Threads) { $Options.Threads = 10}
    if (!$Options.Timeout) { $Options.Timeout = 100 }
    if (!$Options.Push)    { $Options.Push = $false}

    $threads = New-Object object[] $Options.Threads
    $result = @()

    $aup = Get-AUPackages $Name
    $j = 0

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

                $i.Result = Receive-Job $_ -ErrorAction SilentlyContinue -ErrorVariable err
                $i.Error = $err
                if ($i.Result)
                {
                    $i.Updated       = $i.Result -contains 'Package updated'
                    $i.RemoteVersion = ($i.Result -match '^remote version: .+$').Substring(16)
                    $i.NuspecVersion = ($i.Result -match '^nuspec version: .+$').Substring(16)
                    $i.Message       = $i.PackageName + ' '
                    $i.Message      += if ($i.Updated) { 'is updated to ' + $i.RemoteVersion } else { 'has no updates' }

                    if ($Options.Push -and $i.Updated) {
                        $i.Pushed = ($i.Result -like 'Failed to process request*').Length -eq 0
                        if (!$i.Pushed) {
                            $i.Message += ' but push failed!'
                            $i.Error += ($i.Result | sls "Attempting to push" -Context 0,10).ToString()
                        } else { $i.Message += ' and pushed' }
                    }

                    Write-Host '  ' $i.Message
                } else {
                    $i.Updated = $false
                    Write-Host ( "  ERROR: " + $err[0].ToString() )
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

    # Write some stats
    $minutes = ((Get-Date) - $now).TotalMinutes.ToString('#.##')
    $updated = $result | ? Updated | measure | % count
    $pushed  = $result | ? Pushed -eq $true | measure | % count
    $errors  = $result | ? { $_.Error.Length } | measure | % count
    Write-Host ( "Finished {0} packages after {1} minutes." -f $aup.length, $minutes )
    Write-Host ( "{0} packages updated and {1} pushed." -f $updated, $pushed )
    Write-Host ( "{0} errors total." -f $errors )

    # Send email
    if ($errors -and $Options.Mail) {
        $errors = $result | ? Error
        $body =  $errors | % {
            $s = "`nPackage: " + $_.PackageName + "`n"
            $s += $_.Error | out-string
            $s
        }
        send-mail $Options.Mail $body
        Write-Host ("Mail with errors sent to " + $Options.Mail.To)
    }

    $result
}
function send-mail($Mail, $Body) {
    $from = "Update-AUPackages@{0}.{1}" -f $Env:UserName, $Env:ComputerName
    $msg  = New-Object System.Net.Mail.MailMessage $from, $Mail.To
    $msg.Subject    = "$total_errors errors during update"
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
