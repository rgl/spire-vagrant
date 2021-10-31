# About

This is a [SPIFFE](https://spiffe.io/)/[SPIRE](https://github.com/spiffe/spire) playground.

# Usage (Ubuntu 20.04)

Install [swtpm](https://github.com/stefanberger/swtpm) as described at https://github.com/rgl/swtpm-vagrant.

Install [Vagrant](https://github.com/hashicorp/vagrant), [vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt), and the [Ubuntu 20.04 base box](https://github.com/rgl/ubuntu-vagrant).

Start the SPIRE `server` and `agent`s:

```bash
vagrant up --no-destroy-on-error --no-tty
```

Enter the `server` and play with it:

```bash
vagrant ssh server
sudo -i
spire-server entry show
```

# Notes

* The initial SPIFFE trust bundle must be distributed to the nodes using some out-of-band method.

# Reference

* [SPIRE Quickstart](https://spiffe.io/docs/latest/try/spire101/)
* [SPIFFE: In Theory and in Practice](https://www.youtube.com/watch?v=DXE6CDJjDV4)
* [Bridging the Great Divide: SPIFFE/SPIRE for Cross-Cluster Authentication](https://www.youtube.com/watch?v=sjKNsnEYmiU)
* [Securing Edge Systems with TPM 2.0 and SPIRE](https://www.youtube.com/watch?v=3KmvHLHxeRU)
