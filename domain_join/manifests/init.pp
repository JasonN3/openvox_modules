# This class will domain join a system to Active Directory
# The machine's hostname should be set to the FQDN
#
# lint:ignore:140chars
# @param username           The username used to domain join
# @param sensitive_password The password used to domain join
# @param global_admins      An AD group that will have full sudo access on all machines. This will also include ssh access
# @param global_ssh         Ad AD group that will have ssh access to all machines. Sudo privileges can be specified separately
# @param local_admins       A template for an AD group that will have full sudo access on the specific machine. `%HOSTNAME%` will be replaced with the machine's shortname
# @param local_ssh          A template for an AD group that will have ssh access to the specific machine. `%HOSTNAME%` will be replaced  with the machine's shortname
# @param global_nopasswd    Allow sudo by global_admins without a password
# @param local_nopasswd     Allow sudo by local_admins without a password
# @param sssd_home          The directory where all home directories should be created. Defaults to /home
# @param override_domain    Force the name of the domain to join. This can allow the machine's hostname to be set to the short name, but with less sucess
# @param domain_short       The NetBIOS name for the domain
# @param dns_subdomain      The subdomain that the dns records should be registered to. Example: for machine1.sd.example.com, sd would be the subdomain
# @param dnsupdate          If SSSD should create the dns record for the machine. Secure updates are supported
# @param file_header        A commented header to put on each of the managed files. A global file header can be defined using the top-level variable file_header
# @param time_servers       A list of time servers. The domain will automatically be added to the end of the list
# @param configure_chrony   Configures Chrony using time servers in time_servers. Time synchronization is required for kerberos to function
# @param smartcard          Enable smartcard authentication (disabled, enabled, required, lock-on-removal)
# @param ad_trust           Certificate chain for ad certificates (used for smartcard authentication)
# @param update_os_info     Configures a service to update the OS information on the AD object on startup
# lint:endignore
class domain_join (
  String                                                     $username,
  Sensitive[String]                                          $sensitive_password,
  String                                                     $global_admins,
  String                                                     $global_ssh,
  String                                                     $local_admins,
  String                                                     $local_ssh,
  Boolean                                                    $global_nopasswd  = false,
  Boolean                                                    $local_nopasswd   = false,
  String                                                     $sssd_home        = '/home',
  Optional[String]                                           $override_domain  = undef,
  Optional[String]                                           $domain_short     = undef,
  Optional[String]                                           $dns_subdomain    = undef,
  Boolean                                                    $dnsupdate        = true,
  Optional[String]                                           $file_header      = undef,
  Array                                                      $time_servers     = [],
  Boolean                                                    $configure_chrony = true,
  Enum['disabled', 'enabled', 'required', 'lock-on-removal'] $smartcard        = 'disabled',
  Optional[Array[String]]                                    $ad_trust         = undef,
  Boolean                                                    $update_os_info   = false
) {
  if $override_domain {
    $currdomain = $override_domain
    # This is only used if $override_domain is defined
    $forced_fqdn = sprintf('%s.%s', $facts['networking']['hostname'], $currdomain)
  } else {
    if $dns_subdomain {
      $currdomain = regsubst($facts['networking']['domain'], "${dns_subdomain}\\.", '')
    } else {
      $currdomain = $facts['networking']['domain']
    }
  }

  # lint:ignore:top_scope_facts
  if $file_header {
    $file_header_local = $file_header
  } elsif $::file_header {
    $file_header_local = $::file_header
  } else {
    $file_header_local = 'This file is being maintained by Puppet. Do not edit.'
  }
  # lint:endignore

  if $domain_short {
    $shortdomain = split($currdomain, '[.]')[0]
  } else {
    $shortdomain = $domain_short
  }

  if $configure_chrony {
    class { 'chrony':
      servers => $time_servers.reduce({}) |$cumulate, $server| {
        $tmp = merge($cumulate, { "${server}" => ['iburst', 'prefer'] })
        $tmp
      },
      pools   => [$currdomain].reduce({}) |$cumulate, $server| {
        $tmp = merge($cumulate, { "${server}" => ['iburst'] })
        $tmp
      },
    }
  }

  package { 'adcli':
    ensure => installed,
  }

  case $facts['os']['family'] {
    'RedHat': {
      package { 'krb5-workstation':
        ensure => installed,
      }
      package { 'samba-common-tools':
        ensure => installed,
      }
    }
    'Debian': {
      package { 'krb5-workstation':
        ensure => installed,
        name   => 'krb5-user',
      }
      package { 'samba-common-tools':
        ensure => installed,
        name   => 'samba-common-bin',
      }
    }
    default: {
      err('Unknown OS')
    }
  }
  package { 'oddjob-mkhomedir':
    ensure => installed,
  }
  package { 'samba-common':
    ensure => installed,
  }
  package { 'sssd':
    ensure => installed,
  }

  if $ad_trust != undef {
    file { '/etc/sssd/pki':
      ensure  => directory,
      require => Package['sssd'],
    }

    file { '/etc/sssd/pki/sssd_auth_ca_db.pem':
      ensure  => file,
      content => template('domain_join/sssd_auth_ca_db.pem.erb'),
      require => File['/etc/sssd/pki'],
      notify  => [
        Service['sssd'],
        Exec['Trust domain ca chain']
      ],
    }

    exec { 'Trust domain ca chain':
      command     => 'trust anchor /etc/sssd/pki/sssd_auth_ca_db.pem',
      path        => $facts['path'],
      require     => File['/etc/sssd/pki/sssd_auth_ca_db.pem'],
      refreshonly => true,
    }
  }

  if($override_domain) {
    # lint:ignore:140chars
    $command = Sensitive("bash -c 'source /etc/os-release; echo -n \"${$sensitive_password.unwrap}\" | adcli join -H ${forced_fqdn} -D ${currdomain} -U \"${username}\" --stdin-password --os-name=\"\${NAME}\" --os-version=\"\${VERSION}\" --os-service-pack=\"\${VERSION_ID}\"'")
    # lint:endignore
  } else {
    # lint:ignore:140chars
    $command = Sensitive("bash -c 'source /etc/os-release; echo -n \"${$sensitive_password.unwrap}\" | adcli join -D ${currdomain} -U \"${username}\" --stdin-password --os-name=\"\${NAME}\" --os-version=\"\${VERSION}\" --os-service-pack=\"\${VERSION_ID}\"'")
    # lint:endignore
  }

  exec { 'Join':
    command => $command,
    path    => $facts['path'],
    notify  => Service['sssd'],
    creates => '/etc/krb5.keytab',
    require => [
      Package['adcli'],
      Package['krb5-workstation'],
      Package['samba-common'],
      Package['samba-common-tools'],
      Package['sssd'],
      File['/etc/krb5.conf'],
      File['/etc/sssd/sssd.conf'],
    ],
  }

  file { '/etc/systemd/system/update_adcli.service':
    ensure  => file,
    content => template('domain_join/update_adcli.service.erb'),
    require => Exec['Join'],
    notify  => Service['update_adcli'],
  }

  service { 'update_adcli':
    enable => true,
  }

  file { '/etc/krb5.conf':
    ensure  => file,
    content => template('domain_join/krb5.conf.erb'),
    notify  => Service['sssd'],
    require => Package['krb5-workstation'],
  }

  file { '/etc/sssd/sssd.conf':
    ensure  => file,
    content => template('domain_join/sssd.conf.erb'),
    owner   => root,
    group   => root,
    mode    => '0400',
    notify  => Service['sssd'],
    require => Package['sssd'],
  }

  file { '/var/log/sssd/':
    ensure  => directory,
    owner   => sssd,
    group   => sssd,
    require => Package['sssd'],
  }

  service { 'oddjobd':
    ensure  => running,
    enable  => true,
    require => Package['oddjob-mkhomedir'],
  }

  file { '/etc/sudoers.d/admins':
    ensure       => file,
    content      => template('domain_join/sudoers.erb'),
    validate_cmd => '/usr/sbin/visudo -c -f %',
  }

  case $facts['os']['family'] {
    'Debian': {
      $enablesssd = 'pam-auth-update --enable mkhomedir'
      Package { 'authconfig':
        ensure => installed,
        name   => libpam-runtime,
      }
      package { 'libpam-sss':
        ensure => installed,
        before => Package['authconfig'],
      }
      package { 'libnss-sss':
        ensure => installed,
        before => Package['authconfig'],
      }
    }

    'RedHat': {
      case $facts['os']['release']['major'] {
        '7': {
          $enablesssd = 'authconfig --enablesssd --enablesssdauth --enablemkhomedir --update'
          package { 'authconfig':
            ensure => installed,
          }
        }
        '8': {
          $enablesssd = 'authselect select sssd with-mkhomedir --force'
          package { 'authconfig':
            ensure => installed,
            name   => authselect,
          }
        }
        '9': {
          $enablesssd = 'authselect select sssd with-mkhomedir --force'
          package { 'authconfig':
            ensure => installed,
            name   => authselect,
          }
        }
        default: {
          err('Unknown OS')
        }
      }
    }

    default: {
      err('Unknown OS')
    }
  }

  case $smartcard {
    'disabled': {
      $enable_smartcard = ''
    }
    'enabled': {
      $enable_smartcard = 'with-smartcard'
    }
    'required': {
      $enable_smartcard = 'with-smartcard-required'
    }
    'lock-on-removal': {
      $enable_smartcard = 'with-smartcard-lock-on-removal'
    }
    default: {
      err('How??')
    }
  }

  exec { 'Enable SSSD Authentication':
    command     => "${enablesssd} ${enable_smartcard}",
    subscribe   => [
      Exec['Join'],
    ],
    path        => $facts['path'],
    refreshonly => true,
    require     => [
      Package['authconfig'],
      Package['oddjob-mkhomedir'],
      Service['oddjobd'],
      Package['sssd'],
      Service['sssd'],
    ],
  }

  service { 'sssd':
    ensure  => running,
    enable  => true,
    require => [
      File['/etc/sssd/sssd.conf'],
      File['/var/log/sssd'],
      Package['sssd'],
    ],
  }

  if $facts['mountpoints']['/']['device'] == 'overlay' {
    file_line { 'remove systemd from system-auth':
      ensure            => absent,
      path              => '/etc/pam.d/system-auth',
      line              => '',
      match             => '.*pam_systemd\.so.*',
      match_for_absence => true,
      require           => Exec['Enable SSSD Authentication'],
    }

    file_line { 'remove systemd from password-auth':
      ensure            => absent,
      path              => '/etc/pam.d/password-auth',
      match             => '.*pam_systemd\.so.*',
      match_for_absence => true,
      require           => Exec['Enable SSSD Authentication'],
    }
  }
}
