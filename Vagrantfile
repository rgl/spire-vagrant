# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

# see https://github.com/spiffe/spire/releases
CONFIG_SPIRE_VERSION = '1.5.4'
CONFIG_DNS_DOMAIN = 'spire.test'
CONFIG_SERVER_IP = '10.10.0.2'
CONFIG_UBUNTU_AGENT_COUNT = 1   # max 5.
CONFIG_WINDOWS_AGENT_COUNT = 1  # max 5.

require 'ipaddr'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-22.04-amd64'

  config.vm.provider :libvirt do |lv, config|
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    #lv.nested = true
    lv.memory = 1*1024
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.define :server do |config|
    config.vm.hostname = "server.#{CONFIG_DNS_DOMAIN}"
    config.vm.network :private_network,
      ip: CONFIG_SERVER_IP,
      libvirt__dhcp_enabled: false,
      libvirt__forward_mode: 'none'
    config.vm.provision :shell, path: 'provision-base.sh'
    config.vm.provision :shell, path: 'provision-go.sh'
    config.vm.provision :shell, path: 'provision-devid-provisioning-server.sh'
    config.vm.provision :shell, path: 'provision-spire-server.sh', args: [CONFIG_SPIRE_VERSION, CONFIG_UBUNTU_AGENT_COUNT, CONFIG_WINDOWS_AGENT_COUNT]
  end

  (0..CONFIG_UBUNTU_AGENT_COUNT-1).each_with_index do |o, i|
    name = "uagent#{i}"
    ip = IPAddr.new((IPAddr.new CONFIG_SERVER_IP).to_i + 1 + i, Socket::AF_INET).to_s
    config.vm.define name do |config|
      config.vm.hostname = "#{name}.#{CONFIG_DNS_DOMAIN}"
      config.vm.provider :libvirt do |lv, config|
        lv.tpm_type = 'emulator'
        lv.tpm_model = 'tpm-crb'
        lv.tpm_version = '2.0'
      end
      config.vm.network :private_network, ip: ip
      config.vm.provision :hosts do |hosts|
        hosts.autoconfigure = true
        hosts.sync_hosts = true
        hosts.add_localhost_hostnames = false
        hosts.add_host CONFIG_SERVER_IP, ["server.#{CONFIG_DNS_DOMAIN}"]
      end
      config.vm.provision :shell, path: 'provision-base.sh'
      config.vm.provision :shell, path: 'provision-docker.sh'
      config.vm.provision :shell, path: 'provision-docker-compose.sh'
      config.vm.provision :shell, path: 'provision-devid-provisioning-agent.sh'
      config.vm.provision :shell, path: 'provision-spire-agent.sh'
    end
  end

  (0..CONFIG_WINDOWS_AGENT_COUNT-1).each_with_index do |o, i|
    name = "wagent#{i}"
    ip = IPAddr.new((IPAddr.new CONFIG_SERVER_IP).to_i + 1 + 5 + i, Socket::AF_INET).to_s
    config.vm.define name do |config|
      config.vm.box = 'windows-2022-amd64'
      config.vm.hostname = name
      config.vm.provider :libvirt do |lv, config|
        lv.memory = 3*1024
        lv.tpm_type = 'emulator'
        lv.tpm_model = 'tpm-crb'
        lv.tpm_version = '2.0'
        config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
      end
      config.vm.network :private_network, ip: ip
      config.vm.provision :hosts do |hosts|
        hosts.autoconfigure = true
        hosts.sync_hosts = true
        hosts.add_localhost_hostnames = false
        hosts.add_host CONFIG_SERVER_IP, ["server.#{CONFIG_DNS_DOMAIN}"]
      end
      config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-chocolatey.ps1'
      config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-base.ps1'
      config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-spire-agent.ps1', CONFIG_SPIRE_VERSION]
    end
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 'server'
    trigger.run = {
      inline: '''bash -euo pipefail -c \'
mkdir -p share
artifacts=(
  "/var/lib/swtpm-localca/issuercert.pem swtpm-localca-rootca.pem"
)
for artifact in "${artifacts[@]}"; do
  echo "$artifact" | while read artifact path; do
    cp "$artifact" "share/$path"
  done
done
\'
'''
    }
  end
end
