# Library class that will install vault
# This class should not be directly called
#
class hashicorp_vault::lib_binary {
  case $facts['os']['family'] {
    'RedHat': {
      case $facts['os']['name'] {
        'RedHat': {
          file { '/etc/yum.repos.d/vault.repo':
            source => 'https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo',
            owner  => root,
            group  => root,
            mode   => '0444',
          }
        }
        'Fedora': {
          file { '/etc/yum.repos.d/vault.repo':
            source => 'https://rpm.releases.hashicorp.com/fedora/hashicorp.repo',
            owner  => root,
            group  => root,
            mode   => '0444',
          }
        }
      }
      

      package { 'vault':
        ensure => present,
      }
    }
    'Debian': {
      file { '/etc/apt/sources.list.d/hashicorp.list':
        content => "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${$facts['os']['distro']['codename']} main",
        owner   => root,
        group   => root,
        mode    => '0444',
        require => Exec['Download GPG key'],
      }

      package { 'gpg':
        ensure => installed,
      }

      exec { 'Download GPG key':
        command => 'curl https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg',
        path    => $facts['path'],
        creates => '/usr/share/keyrings/hashicorp-archive-keyring.gpg',
        require => Package['gpg'],
      }

      package { 'vault':
        ensure => present,
      }
    }
    default: {
      fail('Unknown OS')
    }
  }
}
