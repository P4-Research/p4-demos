## Introduction ##

This demo shows how to implement MPLS tunnelling using PISCES - the P4-capable Open vSwitch. 

## Design of the P4 program ##

The design is the same as for [BMv2-based demo](https://github.com/P4-Research/p4-demos/tree/master/mpls#design-of-the-p4-program).

## Demo ##

In order to run this demo you need a customized version of PISCES Simulation Environment, which is available at https://github.com/P4-Research/vagrant.

### Network topology ###



### User guide ###

1. Set up a Vagrant environment based on [this instruction](https://github.com/P4-Research/vagrant#setup-virtual-machines-vms).
2. Log into Switch1 VM. Compile OVS with mpls.p4 and run it.

```bash
vagrant ssh switch1
```

```bash
export RTE_SDK=/home/vagrant/ovs/deps/dpdk
export RTE_TARGET=x86_64-native-linuxapp-gcc
export DPDK_DIR=$RTE_SDK
export DPDK_BUILD=$DPDK_DIR/$RTE_TARGET/

cd ~/ovs
sudo ./configure --with-dpdk=$DPDK_BUILD CFLAGS="-g -O2 -Wno-cast-align" \
                   p4inputfile=/vagrant/examples/mpls/mpls.p4 \
                   p4outputdir=./include/p4/src
sudo make clean
sudo make -j 2
```

```bash
sudo /vagrant/examples/run_ovs.sh 
```

3. Log into Switch2 VM and repeat the same step.

4. Only for the first time, initialize OVS bridge:

```bash
sudo /vagrant/examples/init_ovs_br.sh
```

5. On Switch1 VM install flow rules.

```bash
cd /vagrant/examples/mpls/s1/
sudo ./install_flow_rules.sh
```

5. On Switch2 VM install flow rules.

```bash
cd /vagrant/examples/mpls/s2/
sudo ./install_flow_rules.sh
```

6. Log into generator VM and run ping to test network. Note that in this demo we didn't use DPDK-based generator.

```bash
vagrant ssh generator
ping 172.16.0.14
```

7. Ping should work. You can capture MPLS packets using following commands:

```bash
watch sudo ~/ovs/utilities/ovs-ofctl -O OpenFlow15 dump-flows br0
```

Unfortunately, tcpdump cannot be used, because PISCES use DPDK.

## Conclusions ##

It is possible to extend OVS with new tunneling protocol easily. However, the format of flow rules for PISCES is not in line with P4 philosophy (comparing to BMv2), 
because every P4 action (e.g. modify_field()) need to be configured separately instead of using P4 batch action (e.g. push_mpls()).

Nevertheless, PISCES is promising technology, but it needs re-compiling every time the P4 program is modified. Thus, the P4Runtime cannot be used to implement a control plane.