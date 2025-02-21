# Calculate sha-1 thumprint: 
openssl x509 -in client-cert.pem -outform DER | openssl dgst -sha1

# Calculate md5 thumprint: 
openssl x509 -in client-cert.pem -outform DER | openssl dgst -md5

# Serial number: 
openssl x509 -in client-cert.pem -noout -serial

# Check headers EC2: 
sudo tcpdump -A -s 10240 'tcp port 4080 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)' | egrep --line-buffered "^........(GET |HTTP/|POST |HEAD )|^[A-Za-z0-9-]+: " | sed -r 's/^........(GET |HTTP/|POST |HEAD )/\n\1/g'
