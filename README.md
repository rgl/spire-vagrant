# About

This is a [SPIFFE](https://spiffe.io/)/[SPIRE](https://github.com/spiffe/spire) playground.

# Usage (Ubuntu 20.04)

Install [swtpm](https://github.com/stefanberger/swtpm) as described at https://github.com/rgl/swtpm-vagrant.

Install [Vagrant](https://github.com/hashicorp/vagrant), [vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt), [vagrant-hosts](https://github.com/oscar-stack/vagrant-hosts), [Ubuntu 20.04 base box](https://github.com/rgl/ubuntu-vagrant), and [Windows Server 2022 base box](https://github.com/rgl/windows-vagrant).

Start the SPIRE `server`, the `uagent` (Ubuntu), and the `wagent` (Windows) agent nodes:

```bash
vagrant up --no-destroy-on-error --no-tty
```

Enter the `server` node and register the workloads entries:

```bash
vagrant ssh server
sudo -i

# register example unix workload SPIFFE IDs entries (for agents that use
# a TPM DevID to authenticate in spire-server).
trust_domain="$(hostname --domain)"
for uid in 0 1000; do
    for agent_spiffe_id_path in /vagrant/share/*-spiffe-id.txt; do
        spire-server entry create \
            -parentID "$(cat "$agent_spiffe_id_path")" \
            -spiffeID "spiffe://$trust_domain/user-$uid" \
            -selector "unix:uid:$uid"
    done
done

# register example docker workload SPIFFE IDs entries (for agents that use
# a TPM DevID to authenticate in spire-server).
trust_domain="$(hostname --domain)"
for agent_spiffe_id_path in /vagrant/share/*-spiffe-id.txt; do
    spire-server entry create \
        -parentID "$(cat "$agent_spiffe_id_path")" \
        -spiffeID "spiffe://$trust_domain/example-server" \
        -selector 'docker:label:com.docker.compose.project:example-docker-workload' \
        -selector 'docker:label:com.docker.compose.service:server'
    spire-server entry create \
        -parentID "$(cat "$agent_spiffe_id_path")" \
        -spiffeID "spiffe://$trust_domain/example-client" \
        -selector 'docker:label:com.docker.compose.project:example-docker-workload' \
        -selector 'docker:label:com.docker.compose.service:client'
done

# show all
spire-server entry show

# exit the node.
exit
exit
```

Enter the `uagent0` node and fetch a worload SVID for the current user:

```bash
vagrant ssh uagent0

# fetch a SVID for the current workload (a unix process running as uid 1000).
install -d -m 700 svid
spire-agent api fetch x509 -write svid
openssl x509 -in svid/svid.0.pem -text -noout
openssl x509 -in svid/bundle.0.pem -text -noout

# fetch a SVID for the current workload (a unix process running as uid 0).
sudo -i
install -d -m 700 svid
spire-agent api fetch x509 -write svid
openssl x509 -in svid/svid.0.pem -text -noout
openssl x509 -in svid/bundle.0.pem -text -noout

# exit the node.
exit
exit
```

Enter the `uagent0` node and execute an example docker worload:

```bash
vagrant ssh uagent0

# build and run example docker workload.
cd /vagrant/example-docker-workload
docker compose up
```

In another shell, enter the `uagent0` node try the example docker worload:

```bash
vagrant ssh uagent0

# use example docker workload to see their SPIFFE IDs.
http localhost:8080

# dump the example server workload certificate.
# NB this will be a certificate for the server SPIFFE ID (e.g.
#    spiffe://spire.test/example-server) URI X509 SAN (Subject
#    Alternative Name). To include a DNS X509 SAN you would have to register
#    the workload with, e.g., -dns example-server.spire.test.
trust_domain="$(hostname --domain)"
openssl s_client -connect localhost:8443 -servername $trust_domain </dev/null 2>/dev/null | openssl x509 -noout -text
```

# Notes

* The initial SPIFFE trust bundle must be distributed to the nodes using some out-of-band method.
* An agent SPIFFE ID can only be known after the devid-provisioning-agent provisions the TPM DevID.
* A workload can have one or more SPIFFE IDs, like the [example-docker-workload](example-docker-workload), which will have the IDs: `spiffe://spire.test/user-0` and `spiffe://spire.test/example-server` (or `spiffe://spire.test/example-client`).

# Reference

* [SPIRE Quickstart](https://spiffe.io/docs/latest/try/spire101/)
* [SPIFFE: In Theory and in Practice](https://www.youtube.com/watch?v=DXE6CDJjDV4)
* [Bridging the Great Divide: SPIFFE/SPIRE for Cross-Cluster Authentication](https://www.youtube.com/watch?v=sjKNsnEYmiU)
* [Securing Edge Systems with TPM 2.0 and SPIRE](https://www.youtube.com/watch?v=3KmvHLHxeRU)
* DevID Node Attestator (TPM 2.0)
  * [Server plugin: NodeAttestor "tpm_devid"](https://github.com/spiffe/spire/blob/v1.3.0/doc/plugin_server_nodeattestor_tpm_devid.md)
  * [Agent plugin: NodeAttestor "tpm_devid"](https://github.com/spiffe/spire/blob/v1.3.0/doc/plugin_agent_nodeattestor_tpm_devid.md)
  * [Hints about testing the DevID Node Attestator](https://github.com/spiffe/spire/pull/2111#issuecomment-811967536)
  * [TPM 2.0 Keys for Device Identity and Attestation](https://trustedcomputinggroup.org/wp-content/uploads/TCG_IWG_DevID_v1r2_02dec2020.pdf)
  * [devid-provisioning-tool](https://github.com/HewlettPackard/devid-provisioning-tool)
* [Docker Workload Attestor](https://github.com/spiffe/spire/blob/v1.3.0/doc/plugin_agent_workloadattestor_docker.md)
* [go-spiffe spiffe-http example](https://github.com/spiffe/go-spiffe/tree/v2.1.0/v2/examples/spiffe-http)
