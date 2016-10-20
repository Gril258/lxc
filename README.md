lxc
===

This module install lxc on debian and create containers or to only create new debian root

## Dependency

This module has dependency on yelp/netstdlib
add this line to Puppetfile for librarian-puppet
```
mod "yelp/netstdlib", "0.0.1"
```
## Usage

# main class full example
```
      class { 'lxc':
        public_bridge     => 'br0',
        public_macvlan    => 'mvlan0',
        public_interface  => 'eth0',
        public_ip         => '192.168.101.112', # DMZ or public ip
        public_nm         => '255.255.255.248',
        public_gw         => '192.168.101.1',
        public_vlanid     => '10',
        public_vlan       => 'no',
        private_bridge    => 'br1',
        private_macvlan   => 'mvlan1',
        private_ip        => '10.50.0.12',
        private_nm        => '255.255.255.192',
        private_vlanid    => '15',
        private_vlan      => no',
        private_interface => 'eth1',
        public_alias      => [
          {
            id      => '1',
            ip      => '75.743.86.91',
            netmask => '255.255.255.248',
          }
        ],
      }
```

# container resource example via create resources
```
  $container_defaults = {
    'ensure' => 'stopped',
    'private_network' => 'no',
    'public_network' => 'no',
    'template' => 'debian',
    'release' => 'jessie',
  }

  $container_list = {
    'openvpn.infra.ipg' => {
      'ensure' => 'running',
      'lxcpath' => '/var/lib/lxc',
      'public_network' => 'yes',
      'public_ip' => '192.168.101.131/24',
      'public_gw' => '192.168.101.1',
      'private_network' => 'yes',
      'private_ip' => '10.50.0.1/16',
      'private_gw' => '10.50.0.12',
      'allow_tun' => 'yes',
      'autostart' => '1'
    },
  }

create_resources(lxc::container, $container_list, $container_defaults)
```
