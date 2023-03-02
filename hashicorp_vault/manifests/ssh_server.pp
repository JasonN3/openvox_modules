# This class will configure the node to use a host key signed by Hashicorp Vault
# Authentication to the Vault server will be done using the Puppet node's certificate
#
# lint:ignore:140chars
# @param vault_server       The url for the Hashicorp Vault server
# @param vault_public_key   The public key from the SSH engine that will be trusted. vault_ssh_engine is not needed if this is defined
# @param vault_ssh_engine   The engine name within the Hashicorp Vault server for the ssh CA so the key can be downloaded from the server. vault_public_key is not needed if this is defined.<br />NOTICE: Because Hashicorp Vault dynamically generates the page, Puppet will always see the file as changed and will re-write the CA file.
# lint:endignore
class hashicorp_vault::ssh_server (
  String $vault_server,
  Optional[String] $vault_public_key = undef,
  Optional[String] $vault_ssh_engine = undef,
) {
  if ( ! ($vault_public_key or $vault_ssh_engine) ) {
    fail('Either vault_public_key or vault_ssh_engine must be defined')
  }

  require hashicorp_vault::lib_binary

  unless defined(Package['openssh-server']) {
    package { 'openssh-server':
      ensure => installed,
    }
  }

  if ($vault_public_key) {
    file { '/etc/ssh/trusted-user-ca-keys.pem':
      content => $vault_public_key,
      owner   => root,
      group   => root,
      require => Package['openssh-server'],
    }
  } elsif $vault_ssh_engine {
    file { '/etc/ssh/trusted-user-ca-keys.pem':
      source  => "${vault_server}/v1/${vault_ssh_engine}/public_key",
      owner   => root,
      group   => root,
      require => Package['openssh-server'],
    }
  } else {
    fail('This should not be possible')
  }

  file_line { 'TrustedUserCAKeys':
    path    => '/etc/ssh/sshd_config',
    line    => 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem',
    notify  => Service['sshd'],
    require => Package['openssh-server'],
  }

  unless defined(Service['sshd']) {
    service { 'sshd':
      ensure  => running,
      enable  => true,
      require => Package['openssh-server'],
    }
  }

  exec { 'generate ssh certificate':
    # lint:ignore:strict_indent
    command     => @(CMD/L),
      vault login -method=cert name=puppet && \
      vault write -field=signed_key \
      ssh/sign/hosts cert_type=host \
      public_key=@/etc/ssh/ssh_host_rsa_key.pub > /etc/ssh/ssh_host_rsa_key-cert.pub || rm /etc/ssh/ssh_host_rsa_key-cert.pub
      |-CMD
    # lint:endignore
    environment => [
      sprintf('VAULT_ADDR=%s', $vault_server),
      sprintf('VAULT_CLIENT_CERT=/etc/puppetlabs/puppet/ssl/certs/%s.pem', $trusted['certname']),
      sprintf('VAULT_CLIENT_KEY=/etc/puppetlabs/puppet/ssl/private_keys/%s.pem', $trusted['certname']),
    ],
    # lint:ignore:strict_indent
    # lint:ignore:140chars
    onlyif      => @(TEST/L),
      test ! -f /etc/ssh/ssh_host_rsa_key-cert.pub || \
      test "$(date "+%Y%m%d%H%M%S")" -ge $(ssh-keygen -L -f /etc/ssh/ssh_host_rsa_key-cert.pub | grep -w Valid | awk "{print \$5}" | tr -d "\-:T")
      |-TEST
    # lint:endignore
    # lint:endignore
    path        => $facts['path'],
    notify      => Service['sshd'],
    require     => [
      Package['openssh-server'],
      Package['vault'],
    ],
  }

  file_line { 'sshd-HostCertificate':
    ensure  => present,
    path    => '/etc/ssh/sshd_config',
    line    => 'HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub',
    match   => '^HostCertificate .*',
    after   => 'HostKey /etc/ssh/ssh_host_rsa_key',
    notify  => Service['sshd'],
    require => [
      File['/etc/ssh/ssh_host_rsa_key-cert.pub'],
      Package['openssh-server'],
    ],
  }

  file { '/etc/ssh/ssh_host_rsa_key-cert.pub':
    mode    => '0640',
    owner   => 'root',
    group   => 'root',
    notify  => Service['sshd'],
    require => [
      Exec['generate ssh certificate'],
      Package['openssh-server'],
    ],
  }
}
