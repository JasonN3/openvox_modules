# OpenVox Modules

## Description
This is a collection of OpenVox modules that I commonly use that make management of various Linux systems easier.

---
## Modules list
1. [demo_webserver](demo_webserver/README.md)  
FOR DEMO PURPOSES ONLY. This class will install a web server that does NOT start with the machine.
1. [domain_join](domain_join/README.md)  
This module will install and configure the required packages to join an Active Directory domain.
1. [hashicorp_vault](hashicorp_vault/README.md)  
Configires the node to use client/host certificates from Hashicorp Vault
---
## Development
### Option 1:
1. Clone the repo and use the modules  
```bash
git clone https://github.com/JasonN3/openvox_modules.git
```
### Option 2:
1. Edit your Puppetfile so g10k will clone the repo:  
```
mod 'github',
  :git          => 'https://github.com/JasonN3/openvox_modules.git',
  :ref          => 'main',
  :install_path => 'git'
```
2. Edit your environment.conf to include `*install_path*/*mod_name*` from above. For this example, it would be:
```
modulepath = git/github:$basemodulepath
```