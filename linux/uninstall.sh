#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load environment variables from .env file
echo -e "${GREEN}Loading environment variables from .env file...${NC}"
set -a
[[ -f .env ]] && . .env
set +a

rm /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_APP
rm /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_AUTH
rm /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_ADMIN

# Variables
basePath=$(pwd -LP)
basePathPre="$basePath/pre"

echo -e "${GREEN}Uninstalling pre...${NC}"
cd "$basePathPre/setup"
./uninstall.sh

echo -e "${GREEN}Stoping services...${NC}"
systemctl stop primeapps-app
systemctl stop primeapps-admin
systemctl stop primeapps-auth

echo -e "${GREEN}Deleting services...${NC}"
systemctl disable primeapps-app
systemctl disable primeapps-admin
systemctl disable primeapps-auth

echo -e "${GREEN}Deleting $basePath/data...${NC}"
rm -rf "$basePath/pre"

echo -e "${GREEN}Deleting $basePath/services...${NC}"
rm -rf "$basePath/services"

echo -e "${GREEN}Deleting $basePath/.version...${NC}"
rm "$basePath/.version"

echo -e "${CYAN}Completed${NC}"