# Joining RHEL machines directly to Microsoft AD

## Configuring your AD groups for RBAC (Role Based Access Control)
### Access to specific machines
- For each machine create two groups. Both groups will include the short name of the machine. One of the groups will be for machine specific `SSH` access and the other will be machine specific `SUDO` access  
  Example:
  ```
  *DOMAIN* Linux *hostname* ssh access
  *DOMAIN* Linux *hostname* sudo access
  ```
  `*hostname*` is the shortname of the machine  
  `*DOMAIN*` is your domain's short name (optional)

### Access to all machines
- Create two groups for global machine access. One of the groups will be for `SSH` access to all machines and the other will be for `SUDO` access to all machines  
  Example:
  ```
  *DOMAIN* Linux ssh access
  *DOMAIN* Linux sudo access
  ```
  `*DOMAIN*` is your domain's short name (optional)

### Nesting
Nesting within the AD groups is allowed. If you would like to create a group that has access to multiple machines, you do not need to change the configuration on the RHEL machine. Instead you can make the new group a member of the access group for the specific machines. This will allow you to control the access directly from AD.

Example nesting:
- CONOSCO Linux Webserver1 ssh access
  - CONOSCO Linux Webservers ssh access
    - CONOSCO Web Developers
      - User1
      - User2

This nesting will allow you to assign roles (CONOSCO Web Developers) to groups of machines (CONOSCO Linux Webservers ssh access) instead of users to specific machines.

## Domain Joining your Linux machine
1) Install required packages

    ```bash
    dnf install -y chrony krb5-workstation samba-common-tools oddjob-mkhomedir samba-common sssd authselect
    ```

2) Configure SSSD

    Edit `/etc/sssd/sssd.conf` and match the following lines:
    ```ini
    [domain/*DOMAIN*]
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
    simple_allow_groups = *Global_SSH_Access*, *Global_SUDO_Access*, *Machine_SSH_Access*, *Machine_SUDO_Access*
    ignore_group_members = true
    ad_gpo_access_control = disabled
    ad_enable_gc = false
    [sssd]
    services = nss, pam
    config_file_version = 2
    domains = *DOMAIN*
    ```
    `*DOMAIN*` is the FQDN of your domain in ALL CAPITALS. Authentication issues will occur if you do not use all capitals.
    `ldap_idmap_range_size` is optional. This is necessary if you have a large AD environment. Changing this value will cause the uid hash to change so make sure not to change it once the machine is domain joined. 
    `*Global_SSH_Access*`, `*Global_SUDO_Access*`, `*Machine_SSH_Access*`, and `*Machine_SUDO_Access*` are the AD groups you created above for RBAC

    If you would like to enable LDAPS (recommended), add the CA chain to the trust anchors and then add `ad_use_ldaps = true` under the domain section

3) Configure KRB5

    Edit `/etc/krb5.conf` and match the following lines
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
    default_realm = *DOMAIN*


    [realms]

    [domain_realm]
    ```
    `*DOMAIN*` is the FQDN of your domain in ALL CAPITALS. Authentication issues will occur if you do not use all capitals.
    You do not need to specify anything under `realms` or `domain_realm`. SSSD will automatically discover that information from DNS.

4) Configure SUDO access

    Create a file in /etc/sudoers.d using `visudo -f /etc/sudoers.d/DOMAIN` and specify the default sudo access for members of the AD `SUDO` groups.  
    **Make sure to escape any spaces with a `\`**  
    ```sudo
      %*Global_SUDO_Access*   ALL=(ALL) ALL
      %*Machine_SUDO_Access*  ALL=(ALL) ALL
    ```
    `*Global_SUDO_Access*` and `*Machine_SUDO_Access*` are the AD groups you created above for RBAC
    The `%` before the group name indicates that it is a group

    Any other sudo access you would like to grant to AD groups can be defined the same way in separate files or in the same file

5) Ensure the machine's hostname is set to the FQDN. The machine hostname cannot be the shortname

    ```bash
    hostnamectl set-hostname $(hostname -f)
    ```

6) Join the machine with one of the following commands
    - Join with OS information. The OS information is only set during joining.
      ```bash
      source /etc/os-release
      adcli join -U *join_user* --os-name="${NAME}" --os-version="${VERSION}" --os-service-pack="${VERSION_ID}"
      ```
      `*join_user*` is the AD account that will be used to join the machine to the domain. The password that adcli prompts for will not be stored anywhere
   - Join without OS information
      ```bash
      adcli join -U *join_user*
      ```
      `*join_user*` is the AD account that will be used to join the machine to the domain. The password that adcli prompts for will not be stored anywhere

7) Enable logging in with AD
    ```bash
    authselect select sssd with-mkhomedir --force
    ```

## Keeping the OS information up to date

By default, the computer object will not have enough permissions to update its own OS information. Make sure to go in to ADUAC (Active Directory Users and Computers) and grant `SELF` the ability to write each of the OS fields. Once added, the following commands can be used to update the AD object with the latest OS information

```bash
source /etc/os-release; /usr/sbin/adcli update --os-name="${NAME}" --os-version="${VERSION}" --os-service-pack="${VERSION_ID}"
```

This can either be added as a cron job or as a systemd service  
Example service:
```ini
[Unit]
Description=Updates AD with the current OS information
After=sssd.service

[Service]
Type=oneshot
EnvironmentFile=/etc/os-release
ExecStart=/usr/sbin/adcli update --os-name="${NAME}" --os-version="${VERSION}" --os-service-pack="${VERSION_ID}"

[Install]
WantedBy=multi-user.target
```

## Enabling Smartcard authentication
1) Write the certificate chain for your domain to `/etc/sssd/pki/sssd_auth_ca_db.pem`. This does not need to include the certificate for the DCs themselves. It can start at the certificate that signed their certificate
2) Add the certificate to the machines trusted CA list

    ```bash
    trust anchor /etc/sssd/pki/sssd_auth_ca_db.pem
    ```
3) Edit `/etc/sssd/sssd.conf`

    Add the following line within the `[domain/*DOMAIN]` section. This will tell SSSD where to look for the certificate. `userCertificate` is the same location Windows uses so the same smartcard will work on both Linux and Windows
    ```ini
    ldap_user_certificate = userCertificate;binary
    ```

    Add the following lines at the end of `/etc/sssd/sssd.conf`
    ```ini
    [pam]
    pam_cert_auth = true
    ```
4) Edit `/etc/krb5.conf` and add the following lines under `[realms]` replacing `*DOMAIN*` with your domain's FQDN in all uppercase

    ```ini
    *DOMAIN* = {
      pkinit_anchors = DIR:/etc/sssd/pki
      pkinit_kdc_hostname = *DOMAIN*
    }
    ```

5) Enable the feature by using one of the following commands to configure PAM
   - `authselect enable-feature with-smartcard`  
     This will allow smartcard authentication as an option
   - `authselect enable-feature with-smartcard-required`  
     This will require smartcard authentication. Please remember that SSHd will ignore PAM by default when an SSH key
   - `authselect enable-feature with-smartcard-lock-on-removal`  
     This will require smartcard authentication and will lock the machine when the smartcard is removed. Please remember that SSHd will ignore PAM by default when an SSH key

### Enable SSH access using the smartcard certificate
This only seems to work on RHEL 8 or above.  
1) Verify that the smartcard cert will be read properly from AD by running the following command
    ```bash
    sss_ssh_authorizedkeys ${USER}
    ```
    If a public key is not returned, verify that smartcard authentication is configured properly
2) Edit `/etc/ssh/sshd_config` and add the following lines
    ```ini
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
    ```
3) Restart `sshd`
    ```bash
    systemctl restart sshd
    ```

To SSH from a client, use the `ssh` option `PKCS11Provider /usr/lib64/opensc-pkcs11.so`. If the smartcard matches a public key for the user, it will then prompt for the smartcard pin/password.  
```bash
ssh -o PKCS11Provider=/usr/lib64/opensc-pkcs11.so *host*
```



## Testing that has been done
- Disabling a user within AD will immediately block access to the machine.  
  Just like with Windows, anyone who is already logged in will stay logged in.
- Modification to the user's groups is updated during login just like Windows. This is done before checking if they are allowed to log in.
- SSSD is site aware. If you configure sites within `Sites and Services`, SSSD will connect to the appropriate DC.
