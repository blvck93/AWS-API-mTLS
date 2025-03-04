# Calculate sha-1 thumprint: 
openssl x509 -in client-cert.pem -outform DER | openssl dgst -sha1

# Calculate md5 thumprint: 
openssl x509 -in client-cert.pem -outform DER | openssl dgst -md5

# Serial number: 
openssl x509 -in client-cert.pem -noout -serial

# Check headers EC2: 
sudo tail -f /var/log/httpd/access_log

