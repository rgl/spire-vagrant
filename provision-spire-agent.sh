#!/bin/bash
source /vagrant/lib.sh

spire_version="${1:-1.1.0}"; shift || true

# change to the home directory.
cd ~

# ensure the host share directory exists.
if [ ! -d /vagrant/share ]; then
    install -d /vagrant/share
fi

# echo the executed commands to stderr.
set -x

# add the spire-agent user.
groupadd --system spire-agent
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup spire-agent \
    --home /opt/spire-agent \
    spire-agent
install -d -o spire-agent -g spire-agent -m 755 /opt/spire-agent

# download and install.
spire_url="https://github.com/spiffe/spire/releases/download/v$spire_version/spire-$spire_version-linux-x86_64-glibc.tar.gz"
spire_tgz="/vagrant/share/$(basename "$spire_url")"
if [ ! -f "$spire_tgz" ]; then
    wget -qO "$spire_tgz" "$spire_url"
fi
tar xf "$spire_tgz"
install -d /opt/spire-agent/bin
install -d /opt/spire-agent/conf
install -m 755 spire-$spire_version/bin/spire-agent /opt/spire-agent/bin
install -o root -g spire-agent -m 640 /dev/null /opt/spire-agent/conf/environment
cat >/opt/spire-agent/conf/environment <<EOF
SPIRE_AGENT_JOIN_TOKEN=$(cat "/vagrant/share/join-token-$(hostname).txt")
EOF
install -m 644 /vagrant/share/spire-trust-bundle.pem /opt/spire-agent/conf/spire-trust-bundle.pem
install -m 644 /vagrant/spire-agent.conf /opt/spire-agent/conf
install -m 644 /vagrant/spire-agent.service /etc/systemd/system
ln -s /opt/spire-agent/bin/spire-agent /usr/local/bin
rm -rf spire-$spire_version
spire-agent validate -config /opt/spire-agent/conf/spire-agent.conf
systemctl enable spire-agent
systemctl restart spire-agent

# wait for the agent to be healthy.
while [ "$(spire-agent healthcheck 2>/dev/null)" != 'Agent is healthy.' ]; do sleep 1; done

# fetch a SVID for the current workload (a unix process running as uid 0).
install -d -m 700 svid
spire-agent api fetch x509 -write svid
openssl x509 -in svid/svid.0.pem -text -noout
openssl x509 -in svid/bundle.0.pem -text -noout

# fetch a SVID for the current workload (a unix process running as uid 1000).
su -l vagrant <<'EOF'
set -x
install -d -m 700 svid
spire-agent api fetch x509 -write svid
openssl x509 -in svid/svid.0.pem -text -noout
openssl x509 -in svid/bundle.0.pem -text -noout
EOF
