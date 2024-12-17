# Active Directory modülünü yükle
Import-Module ActiveDirectory

# İnaktif kullanıcıları bulmak için gün sayısını ayarlayın
$inactiveDays = 30
$date = (Get-Date).AddDays(-$inactiveDays)

# İnaktif kullanıcıları alın ve son bağlantı tarihine göre sıralayın
$inactiveUsers = Get-ADUser -Filter {LastLogonDate -lt $date} -Properties LastLogonDate, DistinguishedName |
Select-Object Name, SamAccountName, LastLogonDate, DistinguishedName |
Sort-Object LastLogonDate -Descending

# Eğer hiç kullanıcı bulunmazsa, uyarı ver
if ($inactiveUsers.Count -eq 0) {
Write-Host "30 günden fazla süredir oturum açmamış kullanıcı bulunamadı."
exit
}

# Toplam kullanıcı sayısını belirle
$totalUsers = $inactiveUsers.Count

# Kaç gündür etkin olmadığını hesaplayan fonksiyon
function Get-DaysInactive {
param (
[datetime]$LastLogonDate
)
return ((Get-Date) - $LastLogonDate).Days
}

# OU bilgisini çıkartan fonksiyon
function Get-OU {
param (
[string]$DistinguishedName
)
# DistinguishedName'den OU kısmını ayırmak için ',' karakterine göre ayırma ve ilk OU öğesini almak
$ouParts = $DistinguishedName -split ',' | Where-Object { $_ -like "OU=*" }
$ou = $ouParts -join ', ' # OU bilgisini oluştur
return $ou
}

# HTML formatına çevir ve meta etiket ile UTF-8 kodlaması belirt
$htmlReport = "<html><head><meta charset='UTF-8'><style>
table {
width: 80%;
border-collapse: collapse;
font-family: Arial, sans-serif;
margin: 0 auto; /* Tabloyu ortala */
}
th, td {
border: 1px solid #dddddd;
text-align: left;
padding: 8px;
}
th {
background-color: #d9eaf7; /* Açık mavi başlık arka plan rengi */
}
tr:nth-child(even) {
background-color: #f2f9ff; /* Açık mavi satır arka plan rengi */
}
tr:nth-child(odd) {
background-color: #ffffff; /* Beyaz satır arka plan rengi */
}
h1 {
text-align: center; /* Başlığı ortala */
}
p {
text-align: center; /* Toplam kullanıcı sayısını ortala */
font-size: 24px; /* Toplam kullanıcı sayısını büyüt */
}
.body-text {
font-size: 12pt; /* E-posta içeriğinde 12 punto yazı büyüklüğü */
line-height: 1.5; /* Satır yüksekliğini artır */
}
.small-text {
font-size: 12pt; /* Küçük metin boyutu */
}
</style></head><body><h1>Etkin Olmayan AD Kullanıcıları Raporu</h1><p><strong>30 Gündür Etkin Olmayan Kullanıcı Sayısı:</strong> $totalUsers</p>"

# Kullanıcıları tabloya ekle
$htmlReport += "<table><tr><th>Ad Soyad</th><th>Kullanıcı Adı</th><th>AD Klasörü</th><th>Son Giriş Tarihi</th><th>Etkin Olunmayan Gün Sayısı</th></tr>"

foreach ($user in $inactiveUsers) {
$daysInactive = Get-DaysInactive -LastLogonDate $user.LastLogonDate
$ou = Get-OU -DistinguishedName $user.DistinguishedName
# Tarihi gün ay yıl formatında yaz
$formattedLastLogonDate = $user.LastLogonDate.ToString("dd MMM yyyy")
$htmlReport += "<tr><td>$($user.Name)</td><td>$($user.SamAccountName)</td><td>$ou</td><td>$formattedLastLogonDate</td><td>$daysInactive</td></tr>"
}

$htmlReport += "</table></body></html>"

# Geçici dosya yolu
$htmlFilePath = "C:\temp\inactive_users_report.html"

# HTML içeriğini UTF-8 kodlamasıyla geçici dosyaya yaz
$htmlReport | Out-File -FilePath $htmlFilePath -Encoding UTF8

# SMTP sunucusu ayarları
$smtpServer = "192.168.2.1"
$smtpPort = 25
$from = "gonderen_adresi"
$to = "alici_adresi" # Tek bir alıcı e-posta adresi
$subject = "Etkin Olmayan AD Kullanıcıları Raporu" # Mail konusu

# E-posta gönderme işlemi
try {
if (Test-Path $htmlFilePath) {
# Attachment nesnesi oluştur
$attachment = New-Object System.Net.Mail.Attachment($htmlFilePath)
# E-posta gönder
$mailMessage = New-Object system.net.mail.mailmessage
$mailMessage.From = $from
$mailMessage.To.Add($to) # Tek bir alıcı e-posta adresi
$mailMessage.Subject = $subject
$mailMessage.Body = @"
Merhabalar,

30 Gündür Etkin Olmayan AD Kullanıcıları Raporu ektedir.

i̇yi çalışmalar.
"@
$mailMessage.IsBodyHtml = $true
$mailMessage.Attachments.Add($attachment)

# SMTP istemcisi oluştur ve e-postayı gönder
$smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort)
$smtpClient.Send($mailMessage)

# E-posta gönderimi tamamlandıktan sonra dosya nesnesini serbest bırak
$mailMessage.Dispose()
$attachment.Dispose()

Write-Host "E-posta başarıyla gönderildi."
} else {
Write-Host "Dosya bulunamadı: $htmlFilePath"
}
} catch {
Write-Host "E-posta gönderme işlemi başarısız oldu. Hata: $_"
} finally {
# Dosyanın erişilebilir olduğundan emin olana kadar bekle
$maxRetries = 10
$retryInterval = 5 # saniye
$retryCount = 0

while ($retryCount -lt $maxRetries) {
try {
if (Test-Path $htmlFilePath) {
# Dosya işleminden sonra dosya kapama ve serbest bırakma
[System.GC]::Collect() # Çöp toplama işlemi başlat
[System.GC]::WaitForPendingFinalizers() # Çöp toplama işlemlerinin tamamlanmasını bekle
Remove-Item $htmlFilePath -Force
Write-Host "Geçici dosya başarıyla silindi."
break
}
} catch {
Write-Host "Dosya silme işlemi başarısız oldu. Hata: $_. Yeniden deneme..."
Start-Sleep -Seconds $retryInterval
$retryCount++
}
}

if ($retryCount -eq $maxRetries) {
Write-Host "Geçici dosya silme işlemi başarısız oldu. Dosya hala kullanımda olabilir."
}
}