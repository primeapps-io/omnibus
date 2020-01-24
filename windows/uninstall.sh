#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
basePath=$(pwd -W)
basePathPre="$basePath/pre"

echo -e "${GREEN}Uninstalling pre...${NC}"
cd "$basePathPre/setup"
./uninstall.sh

echo -e "${GREEN}Stoping services...${NC}"
net stop "PrimeApps-Auth"
net stop "PrimeApps-App"
net stop "PrimeApps-Admin"
net stop "Nginx"

echo -e "${GREEN}Deleting services...${NC}"
sc delete "PrimeApps-Auth"
sc delete "PrimeApps-App"
sc delete "PrimeApps-Admin"
sc delete "Nginx"

echo -e "${GREEN}Deleting $basePath/data...${NC}"
rm -rf "$basePath/pre"

echo -e "${GREEN}Deleting $basePath/nginx...${NC}"
rm -rf "$basePath/nginx"

echo -e "${GREEN}Deleting $basePath/services...${NC}"
rm -rf "$basePath/services"

echo -e "${GREEN}Deleting $basePath/nginx.zip...${NC}"
rm "$basePath/nginx.zip"

echo -e "${CYAN}Completed${NC}"