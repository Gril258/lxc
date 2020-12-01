# lxc small class
class lxc(
  $public_stp = 'off',
  $public_bridge = undef,
  $public_macvlan = undef,
  $public_interface = undef,
  $public_bond = 'no',
  $public_slaves = [],
  $public_bond_mode = 'active-backup',
  $public_ip = undef,
  $public_nm = undef,
  $public_gw = undef,
  $public_alias = [],
  $public_vlan = 'no',
  $public_vlanid = 0,
  $public_bridge_alias = 'no',
  $private_stp = 'off',
  $private_bridge = undef,
  $private_macvlan = undef,
  $private_bond = 'no',
  $private_slaves = [],
  $private_bond_mode = 'active-backup',
  $private_ip = undef,
  $private_nm = undef,
  $private_interface = undef,
  $private_vlanid = 0,
  $private_vlan = 'no',
  $private_bridge_alias = 'no',
  $private_alias = [],
  $install_only = false,
  $is_aws = false,
  $lxc_version = 'latest'
  ) {

  if $install_only == false {

    $private_nm_cidr = netmask_to_masklen($private_nm)
    if $is_aws == true {
      file { '/etc/network/interfaces.d/lxc-bridge.conf':
        ensure  => present,
        mode    => '0644',
        content => template('lxc/lxc-network.config.erb'),
        notify  => Exec['reload-network']
      }
      exec { 'reload-network':
        command     => '/usr/bin/touch /etc/network/reload-network.lock',
        creates     => '/etc/network/reload-network.lock',
        user        => 'root',
        refreshonly => true,
      }
    }
    else {
      file { '/etc/network/interfaces':
        ensure  => present,
        mode    => '0644',
        content => template('lxc/lxc-network.config.erb'),
        notify  => Exec['reload-network']
      }
      exec { 'reload-network':
        command     => '/usr/sbin/service networking restart && /usr/bin/touch /etc/network/reload-network.lock',
        creates     => '/etc/network/reload-network.lock',
        user        => 'root',
        refreshonly => true,
        require     => [File['/etc/network/interfaces'], Package['bridge-utils', 'vlan', 'ifenslave']]
      }
    }



    concat { '/etc/network/if-up.d/local-containers':
      owner => 'root',
      mode  => '0755',
    }
    package { 'irqbalance':
      ensure => 'latest'
    }
  }
  else {
    # dummy reload-network resorce if only install
    exec { 'reload-network':
      command     => '/usr/bin/touch /etc/network/reload-network.lock',
      creates     => '/etc/network/reload-network.lock',
      user        => 'root',
      refreshonly => true,
    }
  }


# instalation support debian 8
  package { 'lxc':
    ensure  => $lxc_version,
    tag     => 'special',
    require => Exec['apt-update-common-special']
  }
  package { 'bridge-utils':
    ensure  => 'latest',
    tag     => 'special',
    require => Exec['apt-update-common-special']
  }
  case $::lsbdistcodename {
    'buster': {
      package { 'libvirt-clients':
        ensure  => 'latest',
        tag     => 'special',
        require => Exec['apt-update-common-special']
      }
    }
    'stretch': {
      package { 'libvirt-clients':
        ensure  => 'latest',
        tag     => 'special',
        require => Exec['apt-update-common-special']
      }
    }
    'jessie': {
      package { 'libvirt-bin':
        ensure  => 'latest',
        tag     => 'special',
        require => Exec['apt-update-common-special']
      }
    }
    default: {
      fail('lxc - unsupported release')
    }
  }

  package { 'debootstrap':
    ensure  => 'latest',
    tag     => 'special',
    require => Exec['apt-update-common-special']
  }
  package { 'vlan':
    ensure  => 'latest',
    tag     => 'special',
    require => Exec['apt-update-common-special']
  }
  package { 'ifenslave':
    ensure  => 'latest',
    tag     => 'special',
    require => Exec['apt-update-common-special']
  }
}


