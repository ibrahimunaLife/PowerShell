#############################################################################
# AD DC Sağlık Kontrol Scripti
# Author: İbrahim ÜNAL
# Date: 31/10/2024
# Description: AD Domain Controller sağlığını kontrol eder ve sonucu bir log dosyasına kaydeder.
#############################################################################

# Log dosyasının yolunu tanımlayın
$logDir = "C:\DCHealthLogs"
$logFile = "$logDir\DCHealthReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Log dosyasının kaydedileceği dizini oluştur
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir
}

# Log dosyasına yazmak için bir yardımcı fonksiyon
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Output $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

# Başlangıç mesajı
Write-Log "Active Directory Domain Controller sağlık kontrolüne başlanıyor..."

# Değişkenlerde sonuçları tut
$output = ""

# 1. DC Diagnostik Testleri (dcdiag)
Write-Log "1. Domain Controller Diagnostic (dcdiag) testi çalıştırılıyor..."
try {
    $dcdiagResult = dcdiag /v
    Write-Log $dcdiagResult
    $output += "DCDIAG Sonucu:`n$dcdiagResult`n`n"
}
catch {
    $errorMessage = "dcdiag testi başarısız oldu: $($_.Exception.Message)"
    Write-Log $errorMessage
    $output += "$errorMessage`n"
}

# 2. NTDS Durumu (Active Directory Veritabanı durumu)
Write-Log "2. NTDS durumu kontrol ediliyor..."
try {
    $ntdsStatus = Get-Service NTDS
    $ntdsMessage = "NTDS Durumu: $($ntdsStatus.Status)"
    Write-Log $ntdsMessage
    $output += "$ntdsMessage`n"
}
catch {
    $errorMessage = "NTDS durumu alınamadı: $($_.Exception.Message)"
    Write-Log $errorMessage
    $output += "$errorMessage`n"
}

# 3. Replication (Replikasyon) Sağlık Kontrolü
Write-Log "3. Replikasyon durumu kontrol ediliyor..."
try {
    $replicationResult = Get-ADReplicationSummary
    Write-Log "Replikasyon Özeti:"
    Write-Log $replicationResult
    $output += "Replikasyon Özeti:`n$replicationResult`n`n"
}
catch {
    $errorMessage = "Replikasyon kontrolü başarısız oldu: $($_.Exception.Message)"
    Write-Log $errorMessage
    $output += "$errorMessage`n"
}

# 4. FSMO Rolleri Kontrolü
Write-Log "4. FSMO Rolleri kontrol ediliyor..."
try {
    $fsmoRoles = Get-ADDomain | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator
    $fsmoRoles += Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
    $fsmoMessage = "FSMO Rolleri:`n$fsmoRoles"
    Write-Log $fsmoMessage
    $output += "$fsmoMessage`n"
}
catch {
    $errorMessage = "FSMO rolleri alınamadı: $($_.Exception.Message)"
    Write-Log $errorMessage
    $output += "$errorMessage`n"
}

# 5. DNS Durumu Kontrolü
Write-Log "5. DNS servis durumu kontrol ediliyor..."
try {
    $dnsStatus = Get-Service DNS
    $dnsMessage = "DNS Durumu: $($dnsStatus.Status)"
    Write-Log $dnsMessage
    $output += "$dnsMessage`n"
}
catch {
    $errorMessage = "DNS durumu alınamadı: $($_.Exception.Message)"
    Write-Log $errorMessage
    $output += "$errorMessage`n"
}

# 6. Sonuçları Bildirme
Write-Log "Active Directory Domain Controller sağlık kontrolü tamamlandı. Sonuçlar $logFile dosyasına kaydedildi."
Write-Host "Sağlık kontrolü tamamlandı. Detaylar $logFile dosyasında bulunabilir."

# E-posta gönderimi
$smtpServer = "smtp.example.com"  # SMTP sunucu adresi
$smtpPort = 587  # SMTP portu
$fromEmail = "your_email@example.com"  # Gönderen e-posta adresi
$toEmail = "receiver_email@example.com"  # Alıcı e-posta adresi
$subject = "AD DC Sağlık Kontrol Sonucu"
$body = "Sağlık kontrolü tamamlandı. Detaylar aşağıda belirtilmiştir:`n`n$output"

# E-posta gönderim fonksiyonu
Send-MailMessage -From $fromEmail -To $toEmail -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential (Get-Credential)
