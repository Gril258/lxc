# linux container
define lxc::container (
    $ensure = stopped,
    $public_gw = undef,
    $public_ip = undef,
    $public_type = 'macvlan',
    $public_link = 'mvlan0',
    $private_ip = undef,
    $private_gw = undef,
    $private_type = 'macvlan',
    $private_link = 'mvlan1',
    $private_network = 'no',
    $public_network = 'no',
    $allow_tun = 'no',
    $template = 'debian',
    $release = 'jessie',
    $lxcpath = '/var/lib/lxc',
    $logfile = "${lxcpath}/${name}/${name}.log",
    $autostart = '0',
    $config_version = 'simple',
  ) {

  $private_ipaddr = split($private_ip,'/')
  $public_ipaddr = split($public_ip,'/')
  $common_config_name = $template

# Container inicialization
  exec { "lxc-create-${name}":
    command => "lxc-create -n ${name} -t ${template} --lxcpath ${lxcpath} --logfile ${logfile} -- -r ${release}; cp /etc/resolv.conf ${lxcpath}/${name}/rootfs/etc/resolv.conf; echo \"127.0.0.1      localhost\" > ${lxcpath}/${name}/rootfs/etc/hosts; echo \"${private_ipaddr[0]}      ${name}\" >> ${lxcpath}/${name}/rootfs/etc/hosts; chroot ${lxcpath}/${name}/rootfs apt-get update ; chroot ${lxcpath}/${name}/rootfs apt-get install --assume-yes wget vim git iputils-ping ca-certificates python; chroot ${lxcpath}/${name}/rootfs wget https://apt.puppetlabs.com/puppetlabs-release-${release}.deb -O /tmp/puppetlabs-release-${release}.deb; chroot ${lxcpath}/${name}/rootfs dpkg -i /tmp/puppetlabs-release-${release}.deb; chroot ${lxcpath}/${name}/rootfs apt-get update ; chroot ${lxcpath}/${name}/rootfs apt-get install --assume-yes puppet-common;mkdir -p ${lxcpath}/${name}/rootfs/root/.ssh; cp /root/.ssh/authorized_keys ${lxcpath}/${name}/rootfs/root/.ssh/authorized_keys",
    path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin:/usr/local/sbin:/sbin',
    creates => "${lxcpath}/${name}/rootfs",
    timeout => '900',
    require => [Package['lxc'], Exec['reload-network']],
    before  => File["${lxcpath}/${name}"]
  }
  file { "${lxcpath}/${name}":
    ensure  => directory,
    require => Package['lxc'],
    before  => File["${lxcpath}/${name}/config"]
  }
  case $config_version {
    'simple': {
      file { "${lxcpath}/${name}/config":
        ensure  => present,
        mode    => '0644',
        content => template('lxc/lxc-container.config.erb'),
        notify  => Service["container-${name}"],
        before  => File["${lxcpath}/${name}/fstab"]
      }
    }
    'docker': {
      file { "${lxcpath}/${name}/config":
        ensure  => present,
        mode    => '0644',
        content => template('lxc/lxc-container-docker.config.erb'),
        notify  => Service["container-${name}"],
        before  => File["${lxcpath}/${name}/fstab"]
      }
    }
    default: {
      notify { "custom-${lxcpath}/${name}/config":
        message => "no container config version for ${config_version} found, please create custom config file here: ${lxcpath}/${name}/config",
      }
    }
  }
  file { "${lxcpath}/${name}/fstab":
    ensure  => file,
    content => '',
  }


  # link target to default lxc folder
  if $lxcpath != '/var/lib/lxc' {
    file { "/var/lib/lxc/${name}":
      ensure  => 'link',
      target  => "${lxcpath}/${name}",
      require => Exec["lxc-create-${name}"],
    }
  }

  if $private_network == 'yes' {
    service { "container-${name}-route":
      ensure     => $ensure,
      provider   => 'base',
      enable     => true,
      start      => "ip route add ${private_ipaddr[0]}/32 dev ${private_link}",
      status     => "ip route list |grep -o -E \"${private_ipaddr[0]} dev ${private_link}  scope link\"",
      stop       => "ip route del ${private_ipaddr[0]}/32 dev ${private_link}",
      hasrestart => false,
      hasstatus  => true,
      require    => Exec["lxc-create-${name}"],
    }
    concat::fragment { "conatiner-route-persistent-public-${name}":
      order   => "02_${name}",
      target  => '/etc/network/if-up.d/local-containers',
      content => template('lxc/local-containers-private.erb'),
    }
    Internal_network::Route <| |> {
      device => "dev ${private_link}",
    }
  }

  if $public_network == 'yes' {
    service { "container-${name}-public-route":
      ensure     => $ensure,
      provider   => 'base',
      enable     => true,
      start      => "ip route add ${public_ipaddr[0]}/32 dev ${private_link}",
      status     => "ip route list |grep -o -E \"${public_ipaddr[0]} dev ${public_link}  scope link\"",
      stop       => "ip route del ${public_ipaddr[0]}/32 dev ${private_link}",
      hasrestart => false,
      hasstatus  => true,
      require    => Exec["lxc-create-${name}"],
    }
    concat::fragment { "conatiner-route-persistent-public-${name}":
      order   => "02_${name}",
      target  => '/etc/network/if-up.d/local-containers',
      content => template('lxc/local-containers-public.erb'),
    }
  }

  service { "container-${name}":
    ensure     => $ensure,
    provider   => 'base',
    enable     => true,
    start      => "lxc-start -n ${name} -d --logfile ${logfile}",
    status     => "lxc-ls -f|grep -o -E \"${name} + RUNNIN\"",
    stop       => "lxc-stop -n ${name} --logfile ${logfile}",
    hasrestart => false,
    hasstatus  => true,
    require    => Exec["lxc-create-${name}"],
  }

}
