#!/bin/bash
set -euxo pipefail

docker_compose_version="${1:-v2.23.3}"; shift || true

# download.
# see https://github.com/docker/compose/releases
# see https://docs.docker.com/compose/cli-command/#install-on-linux
docker_compose_url="https://github.com/docker/compose/releases/download/$docker_compose_version/docker-compose-linux-$(uname -m)"
wget -qO /tmp/docker-compose "$docker_compose_url"

# install.
install -d /usr/local/lib/docker/cli-plugins
install -m 555 /tmp/docker-compose /usr/local/lib/docker/cli-plugins
rm /tmp/docker-compose
docker compose version
