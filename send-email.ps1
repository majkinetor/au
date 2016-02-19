function Send-Mail($Mail, $Body) {
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
