#!/bin/bash
source /vagrant/lib.sh

trust_domain="$(hostname --domain)"

# install.
install -d -m 750 -g tss /opt/devid-provisioning-agent
install -d /opt/devid-provisioning-agent/bin
install -d /opt/devid-provisioning-agent/conf
install -d -m 750 -g tss /opt/devid-provisioning-agent/devid
install -m 755 /vagrant/share/devid-provisioning-agent /opt/devid-provisioning-agent/bin
install -m 644 /vagrant/share/devid-provisioning-ca.pem /opt/devid-provisioning-agent/conf
install -m 644 /vagrant/devid-provisioning-agent.conf /opt/devid-provisioning-agent/conf

# execute it.
cd /opt/devid-provisioning-agent
./bin/devid-provisioning-agent \
    -config conf/devid-provisioning-agent.conf

# grant the tss group read permissions (spire-agent is in that group) to the devid files.
# NB we could also just grant everyone read access, as everything is public.
chgrp tss devid/*
chmod g+r devid/*

# show the DevID certificate.
openssl x509 -in devid/devid-crt.pem -text -noout

# show the SPIFFE ID.
# see https://github.com/spiffe/spire/blob/v1.4.2/doc/plugin_agent_nodeattestor_tpm_devid.md
devid_fingerprint="$(openssl x509 -in devid/devid-crt.pem -outform der | openssl dgst -sha1 -hex -r | awk '{print $1}')"
spiffe_id="spiffe://$trust_domain/spire/agent/tpm_devid/$devid_fingerprint"
echo -n "$spiffe_id" >"/vagrant/share/$(hostname)-spiffe-id.txt"
echo "$(hostname) SPIFFE ID: $spiffe_id"
