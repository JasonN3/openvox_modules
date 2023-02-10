# Joining RHEL machines directly to Microsoft AD

## AD groups for RBAC control
### Access to specific machines
- For each machine create two groups. Both groups will include the short name of the machine. One of the groups will be for machine specific `SSH` access and the other will be machine specific `SUDO` access  
  Example:
  ```
  DOMAIN Linux *hostname* ssh access
  DOMAIN Linux *hostname* sudo access
  ```
  `*hostname*` is the shortname of the machine

### Access to all machines
- Create a group for `SSH` access to all machines and create a group for `SUDO` access to all machines  
  Example:
  ```
  DOMAIN Linux ssh access
  DOMAIN Linux sudo access
  ```

### Nesting
Nesting within the AD groups is allowed. If you would like to create a group that has access to multiple machines, you do not need to change the configuration on the RHEL machine. Instead you can make the new group a member of the access group for the specific machines. This will allow you to control the access directly from AD.

### Configuration for SSH access
- When configuring `/etc/sssd/sssd.conf`, make sure the `access_provider` is set to `simple` and `simple_allow_groups` is set to a comma delimetered list of the groups you created above. If you would like to be able to grant sudo access without ssh access, you can exclude the sudo groups.
  Example:
  ```ini
  [domain/DOMAIN]
    access_provider = simple
    auth_provider = ad
    chpass_provider = ad
    id_provider = ad
    dyndns_update = true
    override_homedir = /home/%u
    override_shell = /bin/bash
    default_shell = /bin/bash
    ldap_idmap_range_size = 4000000
    cache_credentials = true
    simple_allow_groups = DOMAIN Linux sudo access, DOMAIN Linux ssh access, DOMAIN Linux *hostname* sudo access, DOMAIN Linux *hostname* ssh access
    ignore_group_members = true
    ad_gpo_access_control = disabled
    ad_enable_gc = false
    [sssd]
    services = nss, pam
    config_file_version = 2
    domains = DOMAIN
    ```
    Make sure to set `ad_enable_gc` to `false` if you have multiple domains in your forest. The global catalog may not contain all information about the users which can cause login issues.
- Make sure to update your `/etc/krb5.conf` file to set your default_domain so you don't need to specify the domain for every login
  Example:
  ```init
    [logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

    [libdefaults]
    dns_lookup_realm = true
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = true
    default_ccache_name = KEYRING:persistent:%{uid}
    default_realm = DOMAIN


    [realms]

    [domain_realm]
    ```
    You do not need to specify anything under `realms` or `domain_realm`. SSSD will automatically discover that information from DNS.

### Configuration for SUDO access
- Create a file in /etc/sudoers.d using `visudo -f /etc/sudoers.d/DOMAIN` and specify the default sudo access for members of the AD `SUDO` groups.  
  **Make sure to escape any spaces with a `\`**  
  Example:
  ```sudo
    %DOMAIN\ Linux\ sudo\ access              ALL=(ALL)
    %DOMAIN\ Linux\ *hostname*\ sudo\ access  ALL=(ALL)
  ```
- Any other sudo access you would like to grant to AD groups can be defined the same way.

### Manually joining
1) Make sure the machine's hostname is set to the FQDN. The machine hostname cannot be the shortname
2) Join with OS information. The OS information is only set during joining.
   ```bash
   source /etc/os-release
   adcli join -U *join_user* --os-name="${NAME}" --os-version="${VERSION}" --os-service-pack="${VERSION_ID}"
   ```
   Join without OS information
   ```bash
   adcli join -U *join_user*
   ```
   `*join_user*` is the AD account

## Testing that has been done
- Disabling a user within AD will immediately block access to the machine.  
  Just like with Windows, anyone who is already logged in will stay logged in.
- Modification to the user's groups is updated during login just like Windows. This is done before checking if they are allowed to log in.
- SSSD is site aware. If you configure sites within `Sites and Services`, SSSD will connect to the appropriate DC.
