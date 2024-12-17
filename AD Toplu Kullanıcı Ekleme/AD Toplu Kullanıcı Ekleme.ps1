#Active Directory ile bağlantı kurmalıyız
Import-Module ActiveDirectory

#Oluşturulan dataları içeriye alıyoruz
$ADUsers = Import-Csv C:\CokluKullaniciEkleme.csv -Delimiter ";"

#User Principal Name / domain ismini yazabiliriz
$UPN = "karincalogistics.com"

#data içerisindeki bilgileri değişkenlere atamasını yapıyoruz;
foreach ($User in $ADUsers) {
    $DisplayName = $User.DisplayName
    $username = $User.username
    $password = $User.password
    $firstname = $User.firstname
    $lastname = $User.lastname
    $initials = $User.initials
    $OU = $User.ou 
    $email = $User.email
    $streetaddress = $User.streetaddress
    $city = $User.city
    $zipcode = $User.zipcode
    $state = $User.state
    $telephone = $User.telephone
    $jobtitle = $User.jobtitle
    $company = $User.company
    $department = $User.department
    $description = $User.description	

    #Öncelikle oluşturmaya çalıştığımız kullanıcı var mı yok mu sorgusu yapmalıyız;
    if (Get-ADUser -F { SamAccountName -eq $username }) { 
          Write-Warning "$DisplayName Kullanici daha once acilmis ve aktif durumdadir."
    }
    else {

 #Oluşturulmak istenen kullanıcı yok ise, değişkenlere tanımladığımız bilgiler ile user oluşturuyoruz.
        New-ADUser `
            -SamAccountName $username `
            -UserPrincipalName "$username@$UPN" `
            -Name $DisplayName `
            -GivenName $firstname `
            -Surname $lastname `
            -Initials $initials `
            -Enabled $True `
            -DisplayName $DisplayName `
            -Path $OU `
            -City $city `
            -PostalCode $zipcode `
            -Company $company `
            -State $state `
            -StreetAddress $streetaddress `
            -OfficePhone $telephone `
            -EmailAddress $email `
            -Title $jobtitle `
            -Department $department `
            -description $description `
            -AccountPassword (ConvertTo-secureString $password -AsPlainText -Force) -ChangePasswordAtLogon $True

        Set-ADUser $username -add @{ProxyAddresses="SMTP:$email"} `

        # Members kısmına otomatik olarak eklemek istersen bilgileri burada güncellemeliyiz.
        Add-AdGroupMember -Identity 05_Sistem_Ve_Ag -Members $username `
 
        Write-Host "$DisplayName Acilma Islemi Basarili Olmustur." -ForegroundColor Green
    }
}

Read-Host -Prompt "Tum hesaplar olusturulmustur. Bir Sonraki Hesap Acma Isleminde Gorusmek Uzere =)"