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