#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
basePath=$(pwd -LP)
basePathPre="$basePath/pre"
version="latest"

# Get parameters
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

# Add "v" prefix to version
if [[ ! $version == v* ]] && [ "$version" != "latest" ] ; then
    version="v$version"
fi

# Load environment variables from .env file
echo -e "${GREEN}Loading environment variables from .env file...${NC}"
set -a
[[ -f .env ]] && . .env
set +a

# Set proxy url if http proxy is enabled
if [ "$PRIMEAPPS_PROXY_USE" = "true" ] ; then
    export http_proxy="$PRIMEAPPS_PROXY_URL"
    export https_proxy="$PRIMEAPPS_PROXY_URL"
fi

# Files
fileSetup=${PRIMEAPPS_FILE_SETUP:-"http://file.primeapps.io/pre/setup.zip"}
fileAuth=${PRIMEAPPS_FILE_AUTH:-"http://file.primeapps.io/pre/PrimeApps.Auth.zip"}
fileApp=${PRIMEAPPS_FILE_APP:-"http://file.primeapps.io/pre/PrimeApps.App.zip"}
fileAdmin=${PRIMEAPPS_FILE_ADMIN:-"http://file.primeapps.io/pre/PrimeApps.Admin.zip"}

# Set versioned download links
if [ "$version" != "latest" ] ; then
    fileSetup=${PRIMEAPPS_FILE_SETUP:-"http://file.primeapps.io/pre/$version/setup.zip"}
    fileAuth=${PRIMEAPPS_FILE_AUTH:-"http://file.primeapps.io/pre/$version/PrimeApps.Auth.zip"}
    fileApp=${PRIMEAPPS_FILE_APP:-"http://file.primeapps.io/pre/$version/PrimeApps.App.zip"}
    fileAdmin=${PRIMEAPPS_FILE_ADMIN:-"http://file.primeapps.io/pre/$version/PrimeApps.Admin.zip"}
fi

# Remove PRE (Auth, App, Admin) zip files
cd $basePathPre
rm setup.zip
rm PrimeApps.Auth.zip
rm PrimeApps.App.zip
rm PrimeApps.Admin.zip

# Download PRE
echo -e "${GREEN}Downloading PRE(Auth, App, Admin)...${NC}"
echo -e "${GREEN}Downloading $fileSetup...${NC}"
curl $fileSetup -L --output setup.zip
echo -e "${GREEN}Downloading $fileAuth...${NC}"
curl $fileAuth -L --output PrimeApps.Auth.zip
echo -e "${GREEN}Downloading $fileApp...${NC}"
curl $fileApp -L --output PrimeApps.App.zip
echo -e "${GREEN}Downloading $fileAdmin...${NC}"
curl $fileAdmin -L --output PrimeApps.Admin.zip

# Remove PRE (setup) folders
rm -rf setup

# Unzip PRE (setup)
echo -e "${GREEN}Unzipping PRE (setup)...${NC}"
unzip setup.zip

# Run update.sh
cd "$basePathPre/setup"
./update.sh --version=$version --connection-string="server=localhost;port=5436;username=postgres;password=${PRIMEAPPS_PASSWORD_DATABASE//\//\\/};database=platform;command timeout=0;keepalive=30;maximum pool size=1000;"

# Stop PrimeApps services
echo -e "${GREEN}Stoping primeapps-auth service...${NC}"
systemctl stop primeapps-auth.service

echo -e "${GREEN}Stoping primeapps-auth service...${NC}"
systemctl stop primeapps-app.service

echo -e "${GREEN}Stoping primeapps-auth service...${NC}"
systemctl stop primeapps-admin.service

# Remove PRE (Auth, App, Admin) folders
cd $basePathPre
rm -rf PrimeApps.Auth
rm -rf PrimeApps.App
rm -rf PrimeApps.Admin

# Unzip PRE (Auth, App, Admin)
echo -e "${GREEN}Unzipping PRE (Auth, App, Admin)...${NC}"
unzip PrimeApps.Auth.zip -d PrimeApps.Auth
unzip PrimeApps.App.zip -d PrimeApps.App
unzip PrimeApps.Admin.zip -d PrimeApps.Admin

# Start PrimeApps services
echo -e "${GREEN}Starting primeapps-auth service...${NC}"
systemctl start primeapps-auth.service

echo -e "${GREEN}Starting primeapps-auth service...${NC}"
systemctl start primeapps-app.service

echo -e "${GREEN}Starting primeapps-auth service...${NC}"
systemctl start primeapps-admin.service

# Save version
cd $basePath
cp "$basePathPre/setup/.version" .version

echo -e "${CYAN}Completed${NC}"