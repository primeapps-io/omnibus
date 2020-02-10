#!/bin/bash
#Usage: ./install-linux.sh username

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
su_user=$(id -un)
user=$(logname)
basePath=$(pwd -LP)
basePathPre="$basePath/pre"
basePathPreEscape=${basePathPre//\//\\/} # escape slash
basePathServices="$basePath/services"
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

if [[ ! $version == v* ]]; then
    version="v$version"
fi

fileSetup="https://github.com/primeapps-io/pre/releases/download/$version/setup.zip"
fileDatabase="https://github.com/primeapps-io/pre/releases/download/$version/database.zip"
fileAuth="https://github.com/primeapps-io/pre/releases/download/$version/PrimeApps.Auth.zip"
fileApp="https://github.com/primeapps-io/pre/releases/download/$version/PrimeApps.App.zip"
fileAdmin="https://github.com/primeapps-io/pre/releases/download/$version/PrimeApps.Admin.zip"
urlScheme="http://"

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

# Set url scheme
if [ "$PRIMEAPPS_SSL_USE" = "true" ] ; then
    urlScheme="https://"
fi

# Installing dependencies
echo -e "${GREEN}Installing dependencies${NC}"
apt -v &> /dev/null && apt install -y nginx dotnet-runtime-2.2
which yum &> /dev/null && yum install -y nginx dotnet-runtime-2.2

mkdir pre
cd pre
echo -e "${GREEN}Downloading PRE...${NC}"
if [ ! -f "setup.zip" ]; then 
curl $fileSetup -L --output setup.zip
fi
if [ ! -f "database.zip" ]; then 
curl $fileDatabase -L --output database.zip
fi
if [ ! -f "PrimeApps.App.zip" ]; then 
curl $fileApp -L --output PrimeApps.App.zip
fi
if [ ! -f "PrimeApps.Auth.zip" ]; then
curl $fileAuth -L --output PrimeApps.Auth.zip
fi
if [ ! -f "PrimeApps.Admin.zip" ]; then
curl $fileAdmin -L --output PrimeApps.Admin.zip
fi

# Unzip PRE
echo -e "${GREEN}Unzipping PRE...${NC}"
unzip PrimeApps.App.zip -d PrimeApps.App
chown iboware --recursive PrimeApps.App

unzip PrimeApps.Auth.zip -d PrimeApps.Auth
chown iboware --recursive PrimeApps.Auth

unzip PrimeApps.Admin.zip -d PrimeApps.Admin
chown iboware --recursive PrimeApps.Admin

unzip setup.zip
unzip database.zip

# Install PRE
echo -e "${GREEN}Installing PRE...${NC}"
cd "$basePathPre/setup"
./install.sh

# Change Postgres password
echo -e "${GREEN}Updating PRE...${NC}"
cd "$basePathPre/programs/pgsql/bin"
passwordEscape=${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}
passwordEscape="'${passwordEscape}'"
sudo -u $user bash -c './psql -d postgres -h localhost -p 5436 -c "ALTER USER postgres WITH PASSWORD '${passwordEscape}';"'
systemctl stop postgres-pre.service

cd "$basePathPre/data/pgsql_pre"

# Update Postgres settings for production use
sed -i -e '$a\
host    all             all              0.0.0.0/0              md5\
host    all             all              ::/0                   md5' pg_hba.conf

sed -i -e '$a\
listen_addresses = '"'"'*'"'"'' postgresql.conf

sed -i "s/max_connections = 100/max_connections = 10000/g" postgresql.conf

# Change Redis password
cd "$basePathPre/data/redis_pre"
systemctl stop redis-pre.service
sed -i "s/# requirepass foobared/requirepass ${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" redis.conf
sed -i "s/dir ./\\dir ${basePathPreEscape}\data\redis_pre/g" redis.conf

systemctl daemon-reload
systemctl start redis-pre.service

# Change Minio password
cd "$basePathPre/programs/minio"
systemctl stop minio-pre.service
sleep 3 # Sleep 3 seconds to stop Minio service
sed -i "s/MINIO_ACCESS_KEY/MINIO_ACCESS_KEY_OLD/g" /etc/systemd/system/minio-pre.service
sed -i "s/MINIO_SECRET_KEY/MINIO_SECRET_KEY_OLD/g" /etc/systemd/system/minio-pre.service
sed -i $'/storage-secret-key/a \\\t<env name="MINIO_ACCESS_KEY" value="'"$PRIMEAPPS_STORAGE_ACCESSKEY"'"\/>' /etc/systemd/system/minio-pre.service
sed -i $'/MINIO_ACCESS_KEY"/a \\\t<env name="MINIO_SECRET_KEY" value="'"$PRIMEAPPS_STORAGE_SECRETKEY"'"\/>' /etc/systemd/system/minio-pre.service
systemctl daemon-reload
systemctl start minio-pre.service

echo -e "${GREEN}Creating Auth Service ${NC}"

cp "$basePathPre/setup/service/primeapps-auth.service" primeapps-auth.service
sed -i "s/{{USER}}/$user/g" primeapps-auth.service
sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-auth.service
sed -i "s/{{PORT_AUTH}}/$PRIMEAPPS_PORT_AUTH/g" primeapps-auth.service
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-auth.service
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-auth.service
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-auth.service
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-auth.service
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-auth.service
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_SSL_USE/g" primeapps-auth.service
sed -i "s/{{SENTRY_DSN_AUTH}}/${PRIMEAPPS_SENTRY_DSN_AUTH//\//\\/}/g" primeapps-auth.service

cp primeapps-auth.service /etc/systemd/system/primeapps-auth.service

systemctl start primeapps-auth.service
systemctl enable primeapps-auth.service

echo -e "${GREEN}Creating App Service ${NC}"

cp "$basePathPre/setup/service/primeapps-app.service" primeapps-app.service
sed -i "s/{{USER}}/$user/g" primeapps-app.service
sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-app.service
sed -i "s/{{PORT_APP}}/$PRIMEAPPS_PORT_APP/g" primeapps-app.service
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-app.service
sed -i "s/{{PASSWORD_CACHE}}/${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" primeapps-app.service
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-app.service
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-app.service
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-app.service
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-app.service
sed -i "s/{{ENABLE_JOBS_APP}}/$PRIMEAPPS_ENABLE_JOBS_APP/g" primeapps-app.service
sed -i "s/{{ENABLE_REQUESTLOGGING}}/$PRIMEAPPS_ENABLE_REQUESTLOGGING/g" primeapps-app.service
sed -i "s/{{SMTP_ENABLESSL}}/$PRIMEAPPS_SMTP_ENABLESSL/g" primeapps-app.service
sed -i "s/{{SMTP_HOST}}/$PRIMEAPPS_SMTP_HOST/g" primeapps-app.service
sed -i "s/{{SMTP_PORT}}/$PRIMEAPPS_SMTP_PORT/g" primeapps-app.service
sed -i "s/{{SMTP_USER}}/$PRIMEAPPS_SMTP_USER/g" primeapps-app.service
sed -i "s/{{SMTP_PASSWORD}}/${PRIMEAPPS_SMTP_PASSWORD//\//\\/}/g" primeapps-app.service
sed -i "s/{{CLIENT_ID_APP}}/$PRIMEAPPS_CLIENT_ID_APP/g" primeapps-app.service
sed -i "s/{{CLIENT_SECRET_APP}}/${PRIMEAPPS_CLIENT_SECRET_APP//\//\\/}/g" primeapps-app.service
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_SSL_USE/g" primeapps-app.service
sed -i "s/{{GOOGLEMAPS_APIKEY}}/${PRIMEAPPS_GOOGLEMAPS_APIKEY//\//\\/}/g" primeapps-app.service
sed -i "s/{{ASPOSE_LICENCE}}/${PRIMEAPPS_ASPOSE_LICENCE//\//\\/}/g" primeapps-app.service
sed -i "s/{{SENTRY_DSN_APP}}/${PRIMEAPPS_SENTRY_DSN_APP//\//\\/}/g" primeapps-app.service

cp primeapps-app.service /etc/systemd/system/primeapps-app.service

systemctl start primeapps-app.service
systemctl enable primeapps-app.service

echo -e "${GREEN}Creating Admin Service ${NC}"

cp "$basePathPre/setup/service/primeapps-admin.service" primeapps-admin.service
sed -i "s/{{USER}}/$user/g" primeapps-admin.service
sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-admin.service
sed -i "s/{{PORT_ADMIN}}/$PRIMEAPPS_PORT_ADMIN/g" primeapps-admin.service
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-admin.service
sed -i "s/{{PASSWORD_CACHE}}/${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" primeapps-admin.service
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-admin.service
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-admin.service
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-admin.service
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-admin.service
sed -i "s/{{ENABLE_JOBS_ADMIN}}/$PRIMEAPPS_ENABLE_JOBS_ADMIN/g" primeapps-admin.service
sed -i "s/{{CLIENT_ID_ADMIN}}/$PRIMEAPPS_CLIENT_ID_ADMIN/g" primeapps-admin.service
sed -i "s/{{CLIENT_SECRET_ADMIN}}/${PRIMEAPPS_CLIENT_SECRET_ADMIN//\//\\/}/g" primeapps-admin.service
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_SSL_USE/g" primeapps-admin.service
sed -i "s/{{SENTRY_DSN_ADMIN}}/${PRIMEAPPS_SENTRY_DSN_ADMIN//\//\\/}/g" primeapps-admin.service

cp primeapps-admin.service /etc/systemd/system/primeapps-admin.service

systemctl start primeapps-admin.service
systemctl enable primeapps-admin.service

echo -e "${GREEN}Creating Auth Website ${NC}"

cp "$basePathPre/setup/nginx/proxy-pass" $PRIMEAPPS_DOMAIN_AUTH
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_AUTH/g" $PRIMEAPPS_DOMAIN_AUTH
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_AUTH/g" $PRIMEAPPS_DOMAIN_AUTH
cp $PRIMEAPPS_DOMAIN_AUTH /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_AUTH
sudo ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_AUTH /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_AUTH

echo -e "${GREEN}Creating App Website ${NC}"

cp "$basePathPre/setup/nginx/proxy-pass" $PRIMEAPPS_DOMAIN_APP
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_APP/g" $PRIMEAPPS_DOMAIN_APP
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_APP/g" $PRIMEAPPS_DOMAIN_APP
cp $PRIMEAPPS_DOMAIN_APP /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_APP
sudo ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_APP /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_APP

echo -e "${GREEN}Creating Admin Website ${NC}"

cp "$basePathPre/setup/nginx/proxy-pass" $PRIMEAPPS_DOMAIN_ADMIN
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_ADMIN/g" $PRIMEAPPS_DOMAIN_ADMIN
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_ADMIN/g" $PRIMEAPPS_DOMAIN_ADMIN
cp $PRIMEAPPS_DOMAIN_ADMIN /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_ADMIN
sudo ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_ADMIN /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_ADMIN

cp "$basePathPre/setup/nginx/proxy-pass" $PRIMEAPPS_DOMAIN_STORAGE
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_STORAGE/g" $PRIMEAPPS_DOMAIN_STORAGE
sed -i "s/{{PORT}}/9004/g" $PRIMEAPPS_DOMAIN_STORAGE
sudo ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_STORAGE /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_STORAGE

systemctl daemon-reload
# TODO: If PRIMEAPPS_SSL_CERTIFICATE and PRIMEAPPS_SSL_CERTIFICATEKEY is not empty, replace ssl_certificate and ssl_certificate_key in .conf files


# TODO: backup database with pgBackRest
if [ "$backupDatabase" = "true" ] ; then
    echo -e "${GREEN}Creating database backup...${NC}"
fi

# Save version
cd $basePath
echo $version > .version

echo -e "${CYAN}Completed${NC}"