# domain_join Module


This module will install and configure the required packages to join an Active Directory domain.
## Class domain_join
 This class will domain join a system to Active Directory  
 The machine's hostname should be set to the FQDN  
### Parameters
|Name|Description|
|---|---|
|username|            The username used to domain join|
|sensitive_password|  The password used to domain join|
|global_admins|       An AD group that will have full sudo access on all machines. This will also include ssh access|
|global_ssh|          Ad AD group that will have ssh access to all machines. Sudo privileges can be specified separately|
|local_admins|        A template for an AD group that will have full sudo access on the specific machine. `%HOSTNAME%` will be replaced with the machine's shortname|
|local_ssh|           A template for an AD group that will have ssh access to the specific machine. `%HOSTNAME%` will be replaced  with the machine's shortname|
|global_nopasswd|     Allow sudo by global_admins without a password|
|local_nopasswd|      Allow sudo by local_admins without a password|
|sssd_home|           The directory where all home directories should be created. Defaults to /home|
|override_domain|     Force the name of the domain to join. This can allow the machine's hostname to be set to the short name, but with less sucess|
|domain_short|        The NetBIOS name for the domain|
|dns_subdomain|       The subdomain that the dns records should be registered to. Example: for machine1.sd.example.com, sd would be the subdomain|
|dnsupdate|           If SSSD should create the dns record for the machine. Secure updates are supported|
|file_header|         A commented header to put on each of the managed files. A global file header can be defined using the top-level variable file_header|
|time_servers|        A list of time servers. The domain will automatically be added to the end of the list|
|configure_chrony|    Configures Chrony using time servers in time_servers. Time synchronization is required for kerberos to function|
|smartcard|           Enable smartcard authentication (disabled, enabled, required, lock-on-removal)|
|ad_trust|            Certificate chain for ad certificates (used for smartcard authentication)|
|update_os_info|      Configures a service to update the OS information on the AD object on startup|
|enable_smartcard_ssh|Enable smartcard authentication for SSH (Only seems to work on RHEL 8+)|

---

