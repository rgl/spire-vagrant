#!/bin/bash
source /vagrant/lib.sh

spire_version="${1:-1.1.0}"; shift || true
trust_domain="$(hostname --domain)"

# change to the home directory.
cd ~

# ensure the host share directory exists.
if [ ! -d /vagrant/share ]; then
    install -d /vagrant/share
fi

# echo the executed commands to stderr.
set -x

# add the spire-server user.
groupadd --system spire-server
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup spire-server \
    --home /opt/spire-server \
    spire-server
install -d -o spire-server -g spire-server -m 750 /opt/spire-server

# download and install.
spire_url="https://github.com/spiffe/spire/releases/download/v$spire_version/spire-$spire_version-linux-x86_64-glibc.tar.gz"
spire_tgz="/vagrant/share/$(basename "$spire_url")"
if [ ! -f "$spire_tgz" ]; then
    wget -qO "$spire_tgz" "$spire_url"
fi
tar xf "$spire_tgz"
install -d /opt/spire-server/bin
install -d /opt/spire-server/conf
install -m 755 spire-$spire_version/bin/spire-server /opt/spire-server/bin
install -m 644 /vagrant/spire-server.conf /opt/spire-server/conf
install -m 644 /vagrant/spire-server.service /etc/systemd/system
ln -s /opt/spire-server/bin/spire-server /usr/local/bin
rm -rf spire-$spire_version
systemctl enable spire-server
systemctl restart spire-server

# wait for the server to be healthy.
while [ "$(spire-server healthcheck 2>/dev/null)" != 'Server is healthy.' ]; do sleep 1; done

# share the trust bundle.
spire-server bundle show >/vagrant/share/spire-trust-bundle.pem

# generate the agents join token.
agents='agent0 agent1'
for agent in $agents; do
    spire-server token generate -ttl "$(((12*60*60)))" -spiffeID "spiffe://$trust_domain/$agent" \
        | perl -ne '/Token: (.+)/ && print $1' >/vagrant/share/join-token-$agent.txt
done

# register example workload SPIFFIE IDs.
for uid in 0 1000; do
    for agent in $agents; do
        spire-server entry create \
            -parentID "spiffe://$trust_domain/$agent" \
            -spiffeID "spiffe://$trust_domain/user-$uid" \
            -selector "unix:uid:$uid"
    done
done
