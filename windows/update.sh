#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
basePath=$(pwd -W)
basePathPre="$basePath/pre"
version="latest"

for i in "$@"
do
case $i in
    -v=*|--version=*)
    version="${i#*=}"
    ;;
    *)
    # unknown option
    ;;
esac
done

if [ "$version" == "latest" ] ; then
    version=$(curl -s https://api.github.com/repos/primeapps-io/pre/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
fi

fileAuth="https://github.com/primeapps-io/pre/releases/download/$version/PrimeApps.Auth.zip"
fileApp="https://github.com/primeapps-io/pre/releases/download/$version/PrimeApps.App.zip"
fileAdmin="https://github.com/primeapps-io/pre/releases/download/$version/PrimeApps.Admin.zip"

# Remove PRE (Auth, App, Admin) zip files
cd $basePathPre
rm PrimeApps.Auth.zip
rm PrimeApps.App.zip
rm PrimeApps.Admin.zip

# Download PRE
echo -e "${GREEN}Downloading PRE(Auth, App, Admin)...${NC}"
curl $fileAuth -L --output PrimeApps.Auth.zip
curl $fileApp -L --output PrimeApps.App.zip
curl $fileAdmin -L --output PrimeApps.Admin.zip

# Stop PrimeApps services
echo -e "${GREEN}Stoping primeapps-auth service...${NC}"
net stop "PrimeApps-Auth"

echo -e "${GREEN}Stoping primeapps-auth service...${NC}"
net stop "PrimeApps-App"

echo -e "${GREEN}Stoping primeapps-auth service...${NC}"
net stop "PrimeApps-Admin"

# Remove PRE (Auth, App, Admin) folders
rm -rf PrimeApps.Auth
rm -rf PrimeApps.App
rm -rf PrimeApps.Admin

# Unzip PRE
echo -e "${GREEN}Unzipping PRE(Auth, App, Admin)...${NC}"
unzip PrimeApps.Auth.zip -d PrimeApps.Auth
unzip PrimeApps.App.zip -d PrimeApps.App
unzip PrimeApps.Admin.zip -d PrimeApps.Admin

# Start PrimeApps services
echo -e "${GREEN}Starting primeapps-auth service...${NC}"
net start "PrimeApps-Auth"

echo -e "${GREEN}Starting primeapps-auth service...${NC}"
net start "PrimeApps-App"

echo -e "${GREEN}Starting primeapps-auth service...${NC}"
net start "PrimeApps-Admin"

# TODO: Run migrator here

# Save version
echo $version >> .version

echo -e "${CYAN}Completed${NC}"