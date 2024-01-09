# CERN Tools Installer Script
Small bash script to install CERN Root and Geant4 with its dependencies. 
Currently works only on Ubuntu based distros and MacOS.

# Manual steps
## MacOS:
### Install packages
```
brew install qt@5
brew install doxygen
brew install xquartz
```

### Bash source files not used on MacOS
```
echo 'source /opt/root/bin/thisroot.sh' >> /etc/zshrc 
echo 'source /opt/geant4/bin/geant4.sh' >> /etc/zshrc
```
