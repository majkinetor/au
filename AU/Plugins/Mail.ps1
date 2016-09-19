param(
    $Info,
    [string]   $To,
    [string]   $Server,
    [string]   $UserName,
    [string]   $Password,
    [int]      $Port,
    [string[]] $Attachment,
    [switch]   $EnableSsl,
    [switch]   $SendAlways
)

if (($Info.error_count.total -eq 0) -and !$SendAlways) { return }
$errors_word = if ($Info.error_count.total -eq 1) {'error'} else {'errors' }

# Create mail message
$from = "Update-AUPackages@{0}.{1}" -f $Env:UserName, $Env:ComputerName

$msg = New-Object System.Net.Mail.MailMessage $from, $To
$msg.Subject    = "$($info.error_count.total) errors during update"
$msg.IsBodyHTML = $true

$msg.Body = @"
<body><pre>
$($Info.error_count.total) #errors_word during update
$($info.error_info)
</pre></body>
"@

$Attachment | % { $msg.Attachments.Add($_) }

# Send mail message
$smtp = new-object Net.Mail.SmtpClient($Server)
if ($UserName) { $smtp.Credentials = new-object System.Net.NetworkCredential($UserName, $Password) }
if ($Port)     { $smtp.Port = $Port }
$smtp.EnableSsl = $Mail.EnableSsl
$smtp.Send($msg)

Write-Host "Mail with errors sent to $To"
