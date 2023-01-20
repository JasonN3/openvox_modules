# This class will install a web server and configure the service to NOT start with the machine
#
class webserver () {
  package { 'httpd':
    ensure => installed,
  }

  service { 'httpd':
    enable  => false,
    require => Package['httpd'],
  }
}
