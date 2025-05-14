#!/bin/bash -x

dnf -y install java-11-openjdk-headless openssl


#### download keycloak ####
wget https://github.com/keycloak/keycloak/releases/download/25.0.4/keycloak-25.0.4.zip -O $HOME/keycloak-25.0.4.zip
unzip $HOME/keycloak-25.0.4.zip

#### add keycloak system user/group and folder ####
mv $HOME/keycloak-25.0.4 /opt/keycloak
groupadd keycloak
useradd -r -g keycloak -d /opt/keycloak keycloak
chown -R keycloak: /opt/keycloak
chmod o+x /opt/keycloak/bin/
mkdir /etc/keycloak/

#### deploy Justin's plugin ####
git clone https://github.com/justin-stephenson/scim-keycloak-user-storage-spi.git -b kc_25_updates $HOME/scim-keycloak-user-storage-spi
cd $HOME/scim-keycloak-user-storage-spi/
KEYCLOAK_PATH=/opt/keycloak ./redeploy-plugin.sh

restorecon -R /opt/keycloak

########## setup TLS certificate using IPA CA ###############################
kinit -k
ipa service-add HTTP/$(hostname)
ipa-getcert request -K HTTP/$(hostname) -D $(hostname) \
	            -o keycloak -O keycloak \
		    -m 0600 -M 0644 \
		    -k /etc/pki/tls/private/keycloak.key \
		    -f /etc/pki/tls/certs/keycloak.crt \
		    -w

keytool -import \
    -keystore /etc/pki/tls/private/keycloak.store \
    -file /etc/ipa/ca.crt \
    -alias ipa_ca \
    -trustcacerts -storepass Secret123 -noprompt

chown keycloak:keycloak /etc/pki/tls/private/keycloak.store

# Pull the bridge certificate and add it to Keycloak store

openssl s_client -connect bridge.ipa.test:443 2>/dev/null </dev/null |  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /opt/keycloak/bridge.crt
keytool -importcert -alias bridge -file /opt/keycloak/bridge.crt -keystore /opt/keycloak/keystore.jks -trustcacerts -storepass redhat -noprompt

# Setup keycloak service and config files

cat > /etc/sysconfig/keycloak <<EOF
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=Secret123
#KC_LOG_LEVEL=debug
KC_HOSTNAME=$(hostname)
KC_HTTPS_CERTIFICATE_FILE=/etc/pki/tls/certs/keycloak.crt
KC_HTTPS_CERTIFICATE_KEY_FILE=/etc/pki/tls/private/keycloak.key
KC_HTTPS_TRUST_STORE_FILE=/etc/pki/tls/private/keycloak.store
KC_HTTPS_TRUST_STORE_PASSWORD=Secret123
KC_HTTP_RELATIVE_PATH=/auth
KC_PROXY=edge
EOF

cat > /etc/systemd/system/keycloak.service <<EOF
[Unit]
Description=Keycloak Server
After=network.target

[Service]
Type=idle
EnvironmentFile=/etc/sysconfig/keycloak

User=keycloak
Group=keycloak
ExecStart=/opt/keycloak/bin/kc.sh start --spi-truststore-file-file=/opt/keycloak/keystore.jks --spi-truststore-file-password=redhat --spi-truststore-file-hostname-verification-policy=ANY --log-level=INFO,org.apache.http.wire:debug
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

setenforce 0   # need to determine proper context for this

# Run build stage first
su - keycloak -c '''
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=Secret123
export KC_HOSTNAME=$(hostname):8443
export KC_HTTPS_CERTIFICATE_FILE=/etc/pki/tls/certs/keycloak.crt
export KC_HTTPS_CERTIFICATE_KEY_FILE=/etc/pki/tls/private/keycloak.key
export KC_HTTPS_TRUST_STORE_FILE=/etc/pki/tls/private/keycloak.store
export KC_HTTPS_TRUST_STORE_PASSWORD=Secret123
export KC_HTTP_RELATIVE_PATH=/auth
/opt/keycloak/bin/kc.sh build
'''

systemctl start keycloak

# Setup keycloak for use:

kcadm="/opt/keycloak/bin/kcadm.sh"
$kcadm config truststore --trustpass Secret123 \
    /etc/pki/tls/private/keycloak.store

for count in {1..10}; do
    $kcadm config credentials --server https://$(hostname):8443/auth/ \
        --realm master --user admin --password Secret123

    if [ $? -eq 0 ]; then
        break
    else
        sleep 30
    fi
done

$kcadm create users -r master -s username=testuser1 -s enabled=true -s email=testuser1@ipa.test
$kcadm set-password -r master --username testuser1 --new-password Secret123

##################### Setup OIDC client for IPA tests ##########################
kcreg="/opt/keycloak/bin/kcreg.sh"
$kcreg config credentials --server https://$(hostname):8443/auth/ \
        --realm master --user admin --password Secret123

cat >ipa_client.json <<EOF
{
  "enabled" : true,
  "redirectUris" : [ "https://ipa-ca.ipa.test/ipa/idp/*" ],
  "webOrigins" : [ "https://ipa-ca.ipa.test" ],
  "protocol" : "openid-connect",
  "attributes" : {
    "oauth2.device.authorization.grant.enabled" : "true",
    "oauth2.device.polling.interval": "5"
  }
}
EOF

$kcreg create  -f ipa_client.json  -s clientId=ipa_oidc_client -s secret=Secret123

