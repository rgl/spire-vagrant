#!/bin/bash
source /vagrant/lib.sh

spire_version="${1:-1.5.4}"; shift || true
ubuntu_agent_count="${1:-1}"; shift || true
windows_agent_count="${1:-1}"; shift || true
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
install -m 644 /vagrant/share/devid-provisioning-ca.pem /opt/spire-server/conf
install -m 644 /vagrant/share/swtpm-localca-rootca.pem /opt/spire-server/conf
install -m 644 /vagrant/spire-server.conf /opt/spire-server/conf
install -m 644 /vagrant/spire-server.service /etc/systemd/system
ln -s /opt/spire-server/bin/spire-server /usr/local/bin
rm -rf spire-$spire_version
systemctl enable spire-server
systemctl restart spire-server

# wait for the server to be healthy.
bash -euo pipefail -c "while [ \"\$(spire-server healthcheck 2>/dev/null)\" != 'Server is healthy.' ]; do sleep 1; done"

# share the trust bundle.
spire-server bundle show >/vagrant/share/spire-trust-bundle.pem

# generate the agents join token.
ubuntu_agents="$(seq -f 'uagent%g' 0 $((ubuntu_agent_count-1)))"
windows_agents="$(seq -f 'wagent%g' 0 $((windows_agent_count-1)))"
for agent in $ubuntu_agents $windows_agents; do
    spire-server token generate -ttl "$(((12*60*60)))" -spiffeID "spiffe://$trust_domain/$agent" \
        | perl -ne '/Token: (.+)/ && print $1' >/vagrant/share/$agent-join-token.txt
done

# register example ubuntu workload SPIFFE IDs entries (for agents that use
# a join token to authenticate in spire-server).
for uid in 0 1000; do
    for agent in $ubuntu_agents; do
        spire-server entry create \
            -parentID "spiffe://$trust_domain/$agent" \
            -spiffeID "spiffe://$trust_domain/user-$uid" \
            -selector "unix:uid:$uid"
    done
done

# register example windows workload SPIFFE IDs entries (for agents that use
# a join token to authenticate in spire-server).
for name in vagrant; do
    for agent in $windows_agents; do
        spire-server entry create \
            -parentID "spiffe://$trust_domain/$agent" \
            -spiffeID "spiffe://$trust_domain/user-$name" \
            -selector "windows:user_name:${agent^^}\\$name"
    done
done
