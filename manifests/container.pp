# linux container
define lxc::container (
    $ensure = stopped,
    $public_gw = undef,
    $public_ip = '172.16.100.11',
    $public_type = 'macvlan',
    $public_link = 'mvlan0',
    $public_hwaddr = undef,
    $private_ip = '172.16.100.11',
    $private_gw = undef,
    $private_type = 'macvlan',
    $private_link = 'mvlan1',
    $private_hwaddr = undef,
    $private_network = 'no',
    $private_second_ip = '172.16.100.11',
    $private_second_gw = undef,
    $private_second_type = 'macvlan',
    $private_second_link = 'mvlan1',
    $private_second_network = 'no',
    $public_network = 'no',
    $allow_tun = 'no',
    $template = 'debian',
    $release = 'jessie',
    $lxcpath = '/var/lib/lxc',
    $logfile = "${lxcpath}/${name}/${name}.log",
    $autostart = '0',
    $config_version = 'simple',
    $root_password = 'simplelongpasswordforcontainerpleasechangethis',
    $purge_container_network = false,
    $disable_ipv6 = true,
    $hard_memory_limit = undef,
    $kabernet_enabled = false,
    $download_distro = undef,
  ) {

  $private_ipaddr = split($private_ip,'/')
  $private_second_ipaddr = split($private_second_ip,'/')
  $public_ipaddr = split($public_ip,'/')

  case $template {
    'centos': {
      $release_option = '-R'
      $config_include = $template
      $install_command = "chroot ${lxcpath}/${name}/rootfs yum install -y wget vim git iputils-ping ca-certificates epel-release ${packages};chroot ${lxcpath}/${name}/rootfs yum -y localinstall http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm; chroot ${lxcpath}/${name}/rootfs yum install -y puppet; echo \"${root_password}\"| chroot ${lxcpath}/${name}/rootfs passwd root --stdin;"
    }
    'download': {
      $release_option = "-d ${download_distro} -a amd64 -r"
      $config_include = $download_distro
      case $download_distro {
        'centos': {
          $install_command = "chroot ${lxcpath}/${name}/rootfs yum install -y wget vim git iputils-ping ca-certificates epel-release ${packages};chroot ${lxcpath}/${name}/rootfs yum -y localinstall http://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm; chroot ${lxcpath}/${name}/rootfs yum install -y puppet; echo \"${root_password}\"| chroot ${lxcpath}/${name}/rootfs passwd root --stdin;"
        }
        default: {
          $install_command = "chroot ${lxcpath}/${name}/rootfs apt-get update ; chroot ${lxcpath}/${name}/rootfs apt-get install --assume-yes wget vim git iputils-ping ca-certificates puppet ${packages};"
        }
      }

    }
    default: {
      $config_include = $template
      $install_command = "chroot ${lxcpath}/${name}/rootfs apt-get update ; chroot ${lxcpath}/${name}/rootfs apt-get install --assume-yes wget vim git iputils-ping ca-certificates puppet ${packages};"
      $release_option = '-r'
    }
  }

  $common_config_name = $config_include

  case $release {
    'jessie': {
    $packages = 'cron python'
    }
    'stretch': {
    $packages = 'dirmngr cron python'
    }
    'buster': {
    $packages = 'dirmngr cron python'
    }
    default: {
    $packages = 'cron python'
    }
  }



# Container inicialization
  exec { "lxc-create-${name}":
    command => "lxc-create -n ${name} -t ${template} --lxcpath ${lxcpath} --logfile ${logfile} -- ${release_option} ${release}; cp /etc/resolv.conf ${lxcpath}/${name}/rootfs/etc/resolv.conf; echo \"127.0.0.1      localhost\" > ${lxcpath}/${name}/rootfs/etc/hosts; echo \"${private_ipaddr[0]}      ${name}\" >> ${lxcpath}/${name}/rootfs/etc/hosts;${install_command} mkdir -p ${lxcpath}/${name}/rootfs/root/.ssh; cp /root/.ssh/authorized_keys ${lxcpath}/${name}/rootfs/root/.ssh/authorized_keys",
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

  if $purge_container_network == true and $template == 'debian' {
    file { "${lxcpath}/${name}/rootfs/etc/network/interfaces":
      ensure  => file,
      content => template('lxc/interfaces.erb'),
      require => Exec["lxc-create-${name}"],
    }
  }

  if $disable_ipv6 == true {
    file { "${lxcpath}/${name}/rootfs/etc/sysctl.d/01-ipv6_disable.conf":
      ensure  => file,
      content => 'net.ipv6.conf.all.disable_ipv6 = 1',
      require => Exec["lxc-create-${name}"],
    }
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
    '3': {
      file { "${lxcpath}/${name}/config":
        ensure  => present,
        mode    => '0644',
        content => template('lxc/lxc-container-3.config.erb'),
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
      status     => "ip route list |grep -o -E \"${private_ipaddr[0]} dev ${private_link} scope link\"",
      stop       => "ip route del ${private_ipaddr[0]}/32 dev ${private_link}",
      hasrestart => false,
      hasstatus  => true,
      require    => Exec["lxc-create-${name}"],
    }
    concat::fragment { "conatiner-route-persistent-private-${name}":
      order   => "02_${name}",
      target  => '/etc/network/if-up.d/local-containers',
      content => template('lxc/local-containers-private.erb'),
    }
    #Internal_network::Route <| |> {
    #  device => "dev ${private_link}",
    #}
  }

  if $private_second_network == 'yes' {
    service { "container-${name}-second-route":
      ensure     => $ensure,
      provider   => 'base',
      enable     => true,
      start      => "ip route add ${private_second_ipaddr[0]}/32 dev ${private_second_link}",
      status     => "ip route list |grep -o -E \"${private_second_ipaddr[0]} dev ${private_second_link} scope link\"",
      stop       => "ip route del ${private_second_ipaddr[0]}/32 dev ${private_second_link}",
      hasrestart => false,
      hasstatus  => true,
      require    => Exec["lxc-create-${name}"],
    }
    concat::fragment { "conatiner-route-persistent-private-second-${name}":
      order   => "02_${name}",
      target  => '/etc/network/if-up.d/local-containers',
      content => template('lxc/local-containers-second-private.erb'),
    }
    #Internal_network::Route <| |> {
    #  device => "dev ${private_link}",
    #}
  }

  if $public_network == 'yes' {
    service { "container-${name}-public-route":
      ensure     => $ensure,
      provider   => 'base',
      enable     => true,
      start      => "ip route add ${public_ipaddr[0]}/32 dev ${private_link}",
      status     => "ip route list |grep -o -E \"${public_ipaddr[0]} dev ${public_link} scope link\"",
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
