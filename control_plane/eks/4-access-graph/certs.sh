#!/usr/bin/env bash

set -e

mkdir -p ./certs
cd ./certs

openssl genrsa -aes256 -out ca.key 4096
openssl req -x509 -new -key ca.key -sha256 -days 3652 -out ca.crt -subj '/CN=root'
openssl req -new -out cert.csr -newkey rsa:4096 -nodes -keyout cert.key -subj '/CN=Access Graph'
openssl x509 -req -in cert.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out cert.crt -days 3652 -sha256 \
  -extfile <(printf 'extendedKeyUsage = serverAuth, clientAuth\nsubjectAltName = DNS:teleport-access-graph.teleport-access-graph.svc.cluster.local')

echo "Certificates issued successfully"
