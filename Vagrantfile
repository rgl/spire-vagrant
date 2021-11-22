# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

CONFIG_DNS_DOMAIN = 'spire.test'
CONFIG_SERVER_IP = '10.10.0.2'
CONFIG_AGENT0_IP = '10.10.0.3'
CONFIG_AGENT_COUNT = 1

require 'ipaddr'

agent_ip_addr = IPAddr.new CONFIG_AGENT0_IP

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-20.04-amd64'

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
    config.vm.provision :shell, path: 'provision-spire-server.sh'
  end

  (0..CONFIG_AGENT_COUNT-1).each_with_index do |o, i|
    name = "agent#{i}"
    ip = agent_ip_addr.to_s()
    agent_ip_addr = agent_ip_addr.succ()
    config.vm.define name do |config|
      config.vm.hostname = "#{name}.#{CONFIG_DNS_DOMAIN}"
      config.vm.provider :libvirt do |lv, config|
        lv.tpm_type = 'emulator'
        lv.tpm_model = 'tpm-crb'
        lv.tpm_version = '2.0'
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
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 'server'
    trigger.run = {
      inline: '''bash -euc \'
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
