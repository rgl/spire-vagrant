#!/bin/bash
set -euxo pipefail

# install go.
# see https://go.dev/dl/
# see https://go.dev/doc/install
# see https://github.com/golang/go/tags
# renovate: datasource=github-tags depName=golang/go extractVersion=go(?<version>.+)
artifact_version='1.22.1'
artifact_url=https://go.dev/dl/go$artifact_version.linux-amd64.tar.gz
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
tar xf $artifact_path -C /usr/local
rm $artifact_path

# add go to all users path.
cat >/etc/profile.d/go.sh <<'EOF'
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"
EOF
