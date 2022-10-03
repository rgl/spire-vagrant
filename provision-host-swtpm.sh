#!/bin/bash
set -euxo pipefail

# bail when its already installed.
if [ -r /var/lib/swtpm-localca/issuercert.pem ]; then
    exit 0
fi

# create the swtpm localca.
# NB the localca is created as a side-effect of creating a dummy swtpm instance
#    based on the configuration files at /etc/swtpm* (installed by the
#    swtpm-tools package).
TPMSTATE=/tmp/swtpm-dummy-state
install -d "$TPMSTATE"
swtpm_setup \
    --tpm2 \
    --tpmstate "$TPMSTATE" \
    --create-ek-cert \
    --create-platform-cert \
    --lock-nvram
rm -rf "$TPMSTATE"

# fix the file system permissions.
install -d -o swtpm -g root -o 755 /var/lib/swtpm-localca
chown -R swtpm:root /var/lib/swtpm-localca
