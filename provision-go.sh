#!/bin/bash
set -euxo pipefail

# install go.
# see https://go.dev/dl/
# see https://go.dev/doc/install
artifact_url=https://go.dev/dl/go1.18.4.linux-amd64.tar.gz
artifact_sha=c9b099b68d93f5c5c8a8844a89f8db07eaa58270e3a1e01804f17f4cf8df02f5
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
if [ "$(sha256sum $artifact_path | awk '{print $1}')" != "$artifact_sha" ]; then
    echo "downloaded $artifact_url failed the checksum verification"
    exit 1
fi
tar xf $artifact_path -C /usr/local
rm $artifact_path

# add go to all users path.
cat >/etc/profile.d/go.sh <<'EOF'
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"
EOF
