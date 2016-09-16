# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 16-Sep-2016.

<#
.SYNOPSIS
    Update all automatic packages

.DESCRIPTION
    Function Update-AUPackages will iterate over update.ps1 scripts and execute each. If it detects
    that package is updated it will push it to Chocolatey repository. The function will look for AU 
    packages in the current directory or in the directory pointed to by the global variable au_root.

    For the push to work, specify your API key in the file 'api_key' in the script's directory or use
    cached nuget API key or set environment variable '$Env:api_key'

.EXAMPLE
    Update-AUPackages p* @{ Threads = 5; Timeout = 10 }

    Update all automatic packages in the current directory that start with letter 'p' using 5 threads
    and web timeout of 10 seconds.

.EXAMPLE
    $au_root = 'c:\chocolatey'; updateall @{ Force = $true }

    Force update of all automatic packages in the given directory.

.LINK
    Update-Package

.OUTPUT
    AUPackage[]
#>
function Update-AUPackages {
    [CmdletBinding()]
    param(
        # Filter package names. Supports globs.
        [string] $Name,

        <#
        Hashtable with options:
          Threads     - Number of background jobs to use, by default 10;
          Timeout     - WebRequest timeout in seconds, by default 100;
          Force       - Force package update even if no new version is found;
          Push        - Set to true to push updated packages to chocolatey repository;
          Mail        - Hashtable with mail notification options: To, Server, UserName, Password, Port, EnableSsl;
          Script      - Specify script to be executed at the start and after the update. Script accepts two arguments:
                          $PHASE  - can be 'start' or 'end'
                          $ARG    - in start phase it is the list of packages to be updated;
                                    in end phase it is the info object that contains information about the previous run;
        #>
        [HashTable] $Options=@{}
    )

    $cd = $pwd
    $startTime = get-date

    if (!$Options.Threads) { $Options.Threads = 10 }
    if (!$Options.Timeout) { $Options.Timeout = 100 }
    if (!$Options.Force)   { $Options.Force   = $false }
    if (!$Options.Push)    { $Options.Push    = $false }

    Remove-Job * -force #remove any previously run jobs

    $tmp_dir = "$ENV:Temp\chocolatey\au"
    mkdir -ea 0 $tmp_dir | out-null
    ls $tmp_dir | ? PSIsContainer -eq $false | rm   #clear tmp dir files

    $threads    = New-Object object[] $Options.Threads
    $result     = @()
    $script_err = 0

    $aup = Get-AUPackages $Name
    $j = 0

    Write-Host 'Updating' $aup.Length  'automatic packages at' $($startTime.ToString("s") -replace 'T',' ') $(if ($Options.Force) { "(forced)" } else {})

    if ($Options.Script) { try { & $Options.Script 'START' $aup | Write-Host } catch { Write-Error $_; $script_err += 1 } }
    while( $true ) {

        # Check for completed jobs
        foreach ($job in (Get-Job | ? state -ne 'Running')) {
            $p += 1

            if ( 'Failed', 'Completed' -notcontains $job.State) { 
                Write-Host "Invalid job state for $($job.Name): " + $job.State
            }
            else {
                Write-Verbose ($job.State + ' ' + $job.Name)
                Receive-Job $job | set pkg
                Remove-Job $job

                if ($job.State -eq 'Failed') { continue }

                $message = $pkg.Name + ' '
                $message += if ($pkg.Updated) { 'is updated to ' + $pkg.RemoteVersion } else { 'has no updates' }
                if ($pkg.Updated -and $Options.Push) {
                    $message += if (!$pkg.Pushed) { ' but push failed!' } else { ' and pushed'}
                }
                if ($pkg.Error) {
                    $message = "$($pkg.Name) ERROR: "
                    $message += $pkg.Error.ToString() -split "`n" | % { "`n" + ' '*5 + $_ }
                }
                Write-Host '  ' $message

                $result += $pkg
            }
        }

        # Check if all packages are done
        $job_count = Get-Job | measure | % count
        if ($p -eq $aup.length) { break }

        # Just sleep a bit and repeat if all threads are busy
        if (($job_count -eq $Options.Threads) -or ($j -eq $aup.length)) { sleep 1; continue }

        # Start a new thread
        $package_path = $aup[$j++]
        $package_name = Split-Path $package_path -Leaf
        Write-Verbose "Starting $package_name"
        Start-Job -Name $package_name {
            cd $using:package_path
            $out = "$using:tmp_dir\$using:package_name"

            $global:au_Timeout = $using:Options.Timeout
            $global:au_Force   = $using:Options.Force
            $global:au_Result  = 'pkg'

            try {
                $pkg = ./update.ps1 6> $out
            } catch {
                $pkg.Error = $_
            }
            if (!$pkg) { throw "'$using:package_name' update s script returned nothing" }

            $pkg = $pkg[-1]
            $type = ($pkg | gm).TypeName
            if ($type -ne 'AUPackage') { throw "'$using:package_name' update script didn't return AUPackage but: $type" }

            if ($pkg.$Updated -and $using:Options.Push) {
                $pkg.Result += Push-Package
                if ($LastExitCode -eq 0) { $pkg.Pushed = $true }
            }

            $pkg
        } | Out-Null
    }
    $result = $result | sort PackageName

    $info = get-info
    if ($Options.Script) { try { & $Options.Script 'END' $info | Write-Host } catch { Write-Error $_; $script_err += 1 } }

    @('') + $info.stats + '' | Write-Host
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
    $errors = $result | ? { $_.Error }
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
        $s = "`nPackage: " + $_.Name + "`n"
        $_.Error
    }

    $info
}

function get-stats {
    "Finished {0} packages after {1} minutes." -f $info.packages.length, $info.minutes
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
