#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
basePath=$(pwd -W)
basePathPre="$basePath/pre"
basePathPreEscape=${basePathPre//\//\\/} # escape slash
basePathServices="$basePath/services"
version="latest"
fileNginx=http://nginx.org/download/nginx-1.16.1.zip

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

# Load environment variables from .env file
echo -e "${GREEN}Loading environment variables from .env file...${NC}"
export $(egrep -v '^#' .env | xargs)

# Clone pre git repository
echo -e "${GREEN}Cloning pre git repository...${NC}"
git clone https://github.com/primeapps-io/pre.git

if [ -z $version ] ; then
   git checkout "v$version"
fi

# Install pre
echo -e "${GREEN}Installing pre...${NC}"
cd "$basePathPre/setup"
./install.sh

# Change Postgres password
cd "$basePathPre/programs/pgsql/bin"
./psql -d postgres -p 5436 -c "ALTER USER postgres WITH PASSWORD '${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}';"
net stop "Postgres-PrimeApps"
sleep 3 # Sleep 3 seconds to stop Postgres service
cd "$basePathPre/data/pgsql_pre"
sed -i -e '$a\
host    all             all              0.0.0.0/0              md5\
host    all             all              ::/0                   md5' pg_hba.conf
net start "Postgres-PrimeApps"

# Change Redis password
cd "$basePathPre/data/redis_pre"
net stop "Redis-PrimeApps"
sleep 3 # Sleep 3 seconds to stop Redis service
sed -i "s/{{# requirepass foobared}}/requirepass ${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" redis.windows.conf
net start "Redis-PrimeApps"

# Create PrimeApps services
mkdir $basePathServices
cd $basePathServices

# Create primeapps-auth service
echo -e "${GREEN}Creating primeapps-auth service...${NC}"
cp "$basePathPre/programs/winsw/winsw.exe" primeapps-auth.exe
cp "$basePath/xml/primeapps-auth.xml" primeapps-auth.xml

sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-auth.xml
sed -i "s/{{PORT_AUTH}}/$PRIMEAPPS_PORT_AUTH/g" primeapps-auth.xml
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-auth.xml
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-auth.xml
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-auth.xml
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-auth.xml
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-auth.xml
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_HTTPS_REDIRECTION/g" primeapps-auth.xml
sed -i "s/{{SENTRY_DSN_AUTH}}/${PRIMEAPPS_SENTRY_DSN_AUTH//\//\\/}/g" primeapps-auth.xml

./primeapps-auth.exe install

# Create primeapps-app service
echo -e "${GREEN}Creating primeapps-app service...${NC}"
cp "$basePathPre/programs/winsw/winsw.exe" primeapps-app.exe
cp "$basePath/xml/primeapps-app.xml" primeapps-app.xml

sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-app.xml
sed -i "s/{{PORT_APP}}/$PRIMEAPPS_PORT_APP/g" primeapps-app.xml
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-app.xml
sed -i "s/{{PASSWORD_CACHE}}/${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" primeapps-app.xml
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-app.xml
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-app.xml
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-app.xml
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-app.xml
sed -i "s/{{ENABLE_JOBS_APP}}/$PRIMEAPPS_ENABLE_JOBS_APP/g" primeapps-app.xml
sed -i "s/{{ENABLE_REQUESTLOGGING}}/$PRIMEAPPS_ENABLE_REQUESTLOGGING/g" primeapps-app.xml
sed -i "s/{{SMTP_ENABLESSL}}/$PRIMEAPPS_SMTP_ENABLESSL/g" primeapps-app.xml
sed -i "s/{{SMTP_HOST}}/$PRIMEAPPS_SMTP_HOST/g" primeapps-app.xml
sed -i "s/{{SMTP_PORT}}/$PRIMEAPPS_SMTP_PORT/g" primeapps-app.xml
sed -i "s/{{SMTP_USER}}/$PRIMEAPPS_SMTP_USER/g" primeapps-app.xml
sed -i "s/{{SMTP_PASSWORD}}/${PRIMEAPPS_SMTP_PASSWORD//\//\\/}/g" primeapps-app.xml
sed -i "s/{{CLIENT_ID_APP}}/$PRIMEAPPS_CLIENT_ID_APP/g" primeapps-app.xml
sed -i "s/{{CLIENT_SECRET_APP}}/${PRIMEAPPS_CLIENT_SECRET_APP//\//\\/}/g" primeapps-app.xml
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_HTTPS_REDIRECTION/g" primeapps-app.xml
sed -i "s/{{GOOGLEMAPS_APIKEY}}/${PRIMEAPPS_GOOGLEMAPS_APIKEY//\//\\/}/g" primeapps-app.xml
sed -i "s/{{ASPOSE_LICENCE}}/${PRIMEAPPS_ASPOSE_LICENCE//\//\\/}/g" primeapps-app.xml
sed -i "s/{{SENTRY_DSN_APP}}/${PRIMEAPPS_SENTRY_DSN_APP//\//\\/}/g" primeapps-app.xml

./primeapps-app.exe install

# Create primeapps-admin service
echo -e "${GREEN}Creating primeapps-admin service...${NC}"
cp "$basePathPre/programs/winsw/winsw.exe" primeapps-admin.exe
cp "$basePath/xml/primeapps-admin.xml" primeapps-admin.xml

sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-admin.xml
sed -i "s/{{PORT_ADMIN}}/$PRIMEAPPS_PORT_ADMIN/g" primeapps-admin.xml
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-admin.xml
sed -i "s/{{PASSWORD_CACHE}}/${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" primeapps-admin.xml
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-admin.xml
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-admin.xml
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-admin.xml
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-admin.xml
sed -i "s/{{ENABLE_JOBS_ADMIN}}/$PRIMEAPPS_ENABLE_JOBS_ADMIN/g" primeapps-admin.xml
sed -i "s/{{CLIENT_ID_ADMIN}}/$PRIMEAPPS_CLIENT_ID_ADMIN/g" primeapps-admin.xml
sed -i "s/{{CLIENT_SECRET_ADMIN}}/${PRIMEAPPS_CLIENT_SECRET_ADMIN//\//\\/}/g" primeapps-admin.xml
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_HTTPS_REDIRECTION/g" primeapps-admin.xml
sed -i "s/{{SENTRY_DSN_ADMIN}}/${PRIMEAPPS_SENTRY_DSN_ADMIN//\//\\/}/g" primeapps-admin.xml

./primeapps-admin.exe install

# Install Nginx
cd $basePath
curl $fileNginx -L --output nginx.zip
unzip nginx.zip
mv nginx-1.16.1 nginx

# Update nginx.conf
cd "$basePath/nginx"
mkdir conf.d
cd "$basePath/nginx/conf"
sed -i $'/#gzip  on;/a \\\tserver_names_hash_bucket_size 64;\\\n\tinclude '"$basePath"'/nginx/conf.d/*.conf;' nginx.conf

# Create Nginx configurations for PrimeApps
cd "$basePath/nginx/conf.d"

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_AUTH.conf
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_AUTH/g" $PRIMEAPPS_DOMAIN_AUTH.conf
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_AUTH/g" $PRIMEAPPS_DOMAIN_AUTH.conf

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_APP.conf
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_APP/g" $PRIMEAPPS_DOMAIN_APP.conf
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_APP/g" $PRIMEAPPS_DOMAIN_APP.conf

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_ADMIN.conf
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_ADMIN/g" $PRIMEAPPS_DOMAIN_ADMIN.conf
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_ADMIN/g" $PRIMEAPPS_DOMAIN_ADMIN.conf

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_STORAGE.conf
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_STORAGE/g" $PRIMEAPPS_DOMAIN_STORAGE.conf
sed -i "s/{{PORT}}/9004/g" $PRIMEAPPS_DOMAIN_STORAGE.conf

# TODO: If PRIMEAPPS_SSL_CERTIFICATE and PRIMEAPPS_SSL_CERTIFICATEKEY is not empty, replace ssl_certificate and ssl_certificate_key in .conf files

# Create Nginx service
echo -e "${GREEN}Creating nginx service...${NC}"
cd "$basePath/nginx"
cp "$basePathPre/programs/winsw/winsw.exe" nginx-service.exe
cp "$basePath/xml/nginx.xml" nginx-service.xml

./nginx-service.exe install

# Start PrimeApps services
echo -e "${GREEN}Starting primeapps-auth service...${NC}"
net start "PrimeApps-Auth"

echo -e "${GREEN}Starting primeapps-auth service...${NC}"
net start "PrimeApps-App"

echo -e "${GREEN}Starting primeapps-auth service...${NC}"
net start "PrimeApps-Admin"

# Start Nginx
echo -e "${GREEN}Starting nginx service...${NC}"
net start "Nginx"

# TODO: backup database with pgBackRest
if [ "$backupDatabase" = "true" ] ; then
    echo -e "${GREEN}Creating database backup...${NC}"
fi

echo -e "${CYAN}Completed${NC}"