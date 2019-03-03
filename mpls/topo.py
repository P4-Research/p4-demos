import sys
sys.path.append('../')
from mn.p4_mininet import P4Switch, P4Host
from mininet.topo import Topo
from mininet.net import Mininet
from mininet.log import setLogLevel, info
from mininet.cli import CLI

import argparse

parser = argparse.ArgumentParser(description='Mininet demo')
parser.add_argument('--behavioral-exe', help='Path to behavioral executable', type=str, action="store", required=True)
parser.add_argument('--json', help='Path to JSON config file', type=str, action="store", required=True)
args = parser.parse_args()


class DemoTopo(Topo):
    "Demo topology"

    def __init__(self, sw_path, json_path, **opts):
        # Initialize topology and default options
        Topo.__init__(self, **opts)

        s1 = self.addSwitch('s1',
                            sw_path=sw_path,
                            json_path=json_path,
                            thrift_port=9090)
        s2 = self.addSwitch('s2',
                            sw_path=sw_path,
                            json_path=json_path,
                            thrift_port=9091)
        s3 = self.addSwitch('s3',
                            sw_path=sw_path,
                            json_path=json_path,
                            thrift_port=9092)

        h1 = self.addHost('h1',
                            ip="10.0.10.10/24",
                            mac='00:00:00:00:00:01')
        h2 = self.addHost('h2',
                          ip="10.0.20.10/24",
                          mac='00:00:00:00:00:02')

        self.addLink(s1, h1)
        self.addLink(s3, h2)

        self.addLink(s1, s2)
        self.addLink(s2, s3)


def main():
    topo = DemoTopo(args.behavioral_exe,
                            args.json)

    net = Mininet(topo=topo,
                  host=P4Host,
                  switch=P4Switch,
                  controller=None)
    net.start()

    s1 = net.get('s1')
    s1.setIP('10.0.10.1/24', intf = 's1-eth1')
    s1.setMAC('00:00:00:00:01:01', intf = 's1-eth1')
    s1.setIP('192.168.1.1/24', intf = 's1-eth2')
    s1.setMAC('00:00:00:00:01:02', intf='s1-eth2')

    s2 = net.get('s2')
    s2.setIP('192.168.1.254/24', intf = 's2-eth1')
    s2.setMAC('00:00:00:00:02:01', intf='s2-eth1')
    s2.setIP('192.168.2.254/24', intf = 's2-eth2')
    s2.setMAC('00:00:00:00:02:02', intf='s2-eth2')

    s3 = net.get('s3')
    s3.setIP('10.0.20.1/24', intf='s3-eth1')
    s3.setMAC('00:00:00:00:03:01', intf='s3-eth1')
    s3.setIP('192.168.2.1', intf='s3-eth2')
    s3.setMAC('00:00:00:00:03:02', intf='s3-eth2')

    h1 = net.get('h1')
    h1.setDefaultRoute("dev eth0 via 10.0.10.1")

    h2 = net.get('h2')
    h2.setDefaultRoute("dev eth0 via 10.0.20.1")

    print "Ready !"

    CLI(net)

    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    main()
