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

## Configuration for SSH access
- `/etc/sssd/sssd.conf`
  Make sure the `access_provider` is set to `simple` and `simple_allow_groups` is set to a comma delimetered list of the groups you created above. If you would like to be able to grant sudo access without ssh access, you can exclude the sudo groups.
  Example (Replace DOMAIN with your domain's FQDN in all uppercase):
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
- `/etc/krb5.conf`
  Make sure to set your default_domain so you don't need to specify the domain for every login
  Example:
  ```ini
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

## Configuration for SUDO access
- Create a file in /etc/sudoers.d using `visudo -f /etc/sudoers.d/DOMAIN` and specify the default sudo access for members of the AD `SUDO` groups.  
  **Make sure to escape any spaces with a `\`**  
  Example:
  ```sudo
    %DOMAIN\ Linux\ sudo\ access              ALL=(ALL)
    %DOMAIN\ Linux\ *hostname*\ sudo\ access  ALL=(ALL)
  ```
- Any other sudo access you would like to grant to AD groups can be defined the same way.

## Smartcard configuration
- `/etc/sssd/pki/sssd_auth_ca_db.pem`
  In this file, include the certificate chain for your DCs. It does not need to contain your DCs themselves. During the smartcard process, the client will validate your DC's certificate.
- `/etc/sssd/sssd.conf`
  - Add the following line under `[domain/DOMAIN]`
    ```ini
    ldap_user_certificate = userCertificate;binary
    ```
  - Add the following lines at the end of the file
    ```ini
    [pam]
    pam_cert_auth = true
    ```
- `/etc/krb5.conf`
  Add the following lines under `[realms]` replacing DOMAIN with your domain's FQDN in all uppercase
  ```ini
  DOMAIN = {
    pkinit_anchors = DIR:/etc/sssd/pki
    pkinit_kdc_hostname = DOMAIN
  }
  ```
  `pkinit_anchors` will tell krb5 where to look for the DC's ca chain
  `pkinit_kdc_hostname` is required because the smartcard certificate can contain the domain in lowercase, which will cause the authentication to fail.

- Enable the feature by using `authselect enable-feature with-smartcard`. You can see the other available features by running `authselect list-features sssd`

## Manually joining
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
3) Enable logins using sssd
  ```bash
  authselect select sssd with-mkhomedir --force
  ```

## Keeping the OS information up to date
By default, the computer object will not have enough permissions to update its own OS information. Make sure to go in to AD and grant `SELF` the ability to write each of the OS fields. Once added, the following commands can be used to update the AD object with the latest OS information
```bash
source /etc/os-release; /usr/sbin/adcli update --os-name="${NAME}" --os-version="${VERSION}" --os-service-pack="${VERSION_ID}"
```

## Testing that has been done
- Disabling a user within AD will immediately block access to the machine.  
  Just like with Windows, anyone who is already logged in will stay logged in.
- Modification to the user's groups is updated during login just like Windows. This is done before checking if they are allowed to log in.
- SSSD is site aware. If you configure sites within `Sites and Services`, SSSD will connect to the appropriate DC.
