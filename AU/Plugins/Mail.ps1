param(
    $Info,
    [string]   $To,
    [string]   $Server,
    [string]   $UserName,
    [string]   $Password,
    [int]      $Port,
    [string[]] $Attachment,
    [switch]   $EnableSsl,
    # Do not send only on errors
    [switch]   $SendAlways
)

if (($Info.error_count.total -eq 0) -and !$SendAlways) {
    Write-Host '  Mail not sent as there are no errors (override with SendAlways param)'
    return
}

$errors_word = if ($Info.error_count.total -eq 1) {'error'} else {'errors' }

# Create mail message
$from = "Update-AUPackages@{0}.{1}" -f $Env:UserName, $Env:ComputerName

$msg = New-Object System.Net.Mail.MailMessage $from, $To
$msg.IsBodyHTML = $true

if ($Info.error_count.total -eq 0) {
    $msg.Subject = "AU: run was OK"
    $msg.Body = $Info.stats | Out-String
}
else {
    $context = "with errors "
    $msg.Subject    = "AU: $($info.error_count.total) $errors_word during update"
    $msg.Body = @"
<body><pre>
$($Info.error_count.total) $errors_word during update.

$($info.error_info)
</pre></body>
"@
}

$Attachment | % { if ($_) { $msg.Attachments.Add($_)} }

# Send mail message
$smtp = new-object Net.Mail.SmtpClient($Server)
if ($UserName) { $smtp.Credentials = new-object System.Net.NetworkCredential($UserName, $Password) }
if ($Port)     { $smtp.Port = $Port }
$smtp.EnableSsl = $EnableSsl
$smtp.Send($msg)

Write-Host "Mail ${context}sent to $To"
