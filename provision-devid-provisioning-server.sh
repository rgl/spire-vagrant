#!/bin/bash
source /vagrant/lib.sh

devid_provisioning_version="${1:-b912ef2c19571093dfacd0a6721dd1e6f6299768}"; shift || true
cfssl_version="${1:-1.6.1}"; shift || true
trust_domain="$(hostname --domain)"

# echo the executed commands to stderr.
set -x

# ensure the host share directory exists.
if [ ! -d /vagrant/share ]; then
    install -d /vagrant/share
fi

# download and install cfssl.
for name in cfssl cfssljson; do
    artifact_url="https://github.com/cloudflare/cfssl/releases/download/v$cfssl_version/${name}_${cfssl_version}_linux_amd64"
    artifact_path="/vagrant/share/$(basename "$artifact_url")"
    if [ ! -f "$artifact_path" ]; then
        wget -qO "$artifact_path" "$artifact_url"
    fi
    install -m 755 $artifact_path /usr/local/bin/$name
done

# change to the home directory.
cd ~

if [ ! -d devid-provisioning-tool ]; then
    git clone https://github.com/HewlettPackard/devid-provisioning-tool.git
fi

# checkout the required version.
cd ~/devid-provisioning-tool
git checkout $devid_provisioning_version

# add the devid-provisioning-server user.
groupadd --system devid-provisioning-server
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup devid-provisioning-server \
    --home /opt/devid-provisioning-server \
    devid-provisioning-server
install -d -o devid-provisioning-server -g devid-provisioning-server -m 750 /opt/devid-provisioning-server

# build.
make build

# install.
install -d /opt/devid-provisioning-server/bin
install -d /opt/devid-provisioning-server/conf
install -m 755 bin/server/provisioning-server /opt/devid-provisioning-server/bin/devid-provisioning-server
install -m 755 bin/agent/provisioning-agent /vagrant/share/devid-provisioning-agent
install -m 644 /vagrant/share/swtpm-localca-rootca.pem /opt/devid-provisioning-server/conf
install -m 644 /vagrant/devid-provisioning-server.conf /opt/devid-provisioning-server/conf
install -m 644 /vagrant/devid-provisioning-server.service /etc/systemd/system
pushd /opt/devid-provisioning-server/conf
cfssl gencert -initca /vagrant/devid-provisioning-ca-csr.json \
    | cfssljson -bare devid-provisioning-ca -
cfssl gencert \
    -ca devid-provisioning-ca.pem \
    -ca-key devid-provisioning-ca-key.pem \
    /vagrant/devid-provisioning-server-csr.json \
    | cfssljson -bare devid-provisioning-server
openssl pkcs8 -topk8 -nocrypt -in devid-provisioning-ca-key.pem -out devid-provisioning-ca.pkcs8-key.pem
chmod 640 *-key.pem
chgrp devid-provisioning-server *-key.pem
popd
systemctl enable devid-provisioning-server
systemctl restart devid-provisioning-server

# share the provisioning ca certificate with the host.
cp /opt/devid-provisioning-server/conf/devid-provisioning-ca.pem /vagrant/share
