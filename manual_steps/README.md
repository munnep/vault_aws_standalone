# Deploy vault

The following are the notes for deploying a vault environment that you can stop/start and stores the data on disk. You can do this using Vault on your local machine

- Install Vault
```
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

- create some self signed certificates to be used
```
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=Acme Root CA" -out ca.crt

openssl req -newkey rsa:2048 -nodes -keyout server.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=127.0.0.1.nip.io" -out server.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:127.0.0.1.nip.io") -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt
```
- create a file called `config_https.hcl`
```
storage "raft" {
  path    = "./data"
  node_id = "node1"
}

listener "tcp" {
  address     = "127.0.0.1.nip.io:8200"
  tls_disable = "false"
  tls_cert_file = "./server.crt"
  tls_key_file  = "./server.key"
}

api_addr = "https://127.0.0.1.nip.io:8200"
cluster_addr = "https://127.0.0.1.nip.io:8201"
ui = true
```
- create a directory where the vault storage will be stored
```
mkdir -p ./data
```
- start the server
```
vault server -config=config_https.hcl
```
- now we need to initialize vault. This initialize will only work on Vault environments that don't have any data yet
```
export VAULT_ADDR='https://127.0.0.1.nip.io:8200'
vault operator init
```
- you get the following information that you will need to store in a secure place
```
Unseal Key 1: 4qCh6eqDrcl6BqP13WOljY1BAAGz9GSObkXgXMVKzC3I
Unseal Key 2: H1W9d/oeqbH7y5HoA8kfNj9V3tAxGhsFu6I+Fp9OG2/K
Unseal Key 3: 8+gGAuch12Vd1t6witk7ioapUWPGNPCLM4HJKVEPsJ3v
Unseal Key 4: 4k+GBzEFFYWv5JsBuRv/FBuIP2XZAHXAOpNv4TQKKHUj
Unseal Key 5: O3O4jtxQbuYsIiOGJHWV59JRFMQzZrBG65U/s76aitbm


Initial Root Token: hvs.9UaSUxZh0FP2BHUGESbmU8Sm

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

- Vault is currently sealed and has to be unsealed
Unsealing has to happen every time Vault starts. It can be done via the API and via the command line. To unseal the Vault, you must have the threshold number of unseal keys. In the output above, notice that the "key threshold" is 3. This means that to unseal the Vault, you need 3 of the 5 keys that were generated.

you will have to do this 3 times
```
vault operator unseal
```
- Now you can login using the root token
```
vault login
```