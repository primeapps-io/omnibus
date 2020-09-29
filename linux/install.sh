#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
basePath=$(pwd -LP)
basePathPre="$basePath/pre"
basePathPreRedis="$basePathPre/data/redis_pre"
basePathPreEscape=${basePathPre//\//\\/} # escape slash
basePathPreRedisEscape=${basePathPreRedis//\//\\/} # escape slash

basePathServices="$basePath/services"
version="latest"
user=$(logname)
urlScheme="http://"

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

# Set url scheme
if [ "$PRIMEAPPS_SSL_USE" = "true" ] ; then
    urlScheme="https://"
fi

# Files
fileSetup=${PRIMEAPPS_FILE_SETUP:-"http://file.primeapps.io/pre/setup.zip?_=$(date +%s)"}
fileDatabase=${PRIMEAPPS_FILE_DATABASE:-"http://file.primeapps.io/pre/database.zip?_=$(date +%s)"}
fileAuth=${PRIMEAPPS_FILE_AUTH:-"http://file.primeapps.io/pre/PrimeApps.Auth.zip?_=$(date +%s)"}
fileApp=${PRIMEAPPS_FILE_APP:-"http://file.primeapps.io/pre/PrimeApps.App.zip?_=$(date +%s)"}
fileAdmin=${PRIMEAPPS_FILE_ADMIN:-"http://file.primeapps.io/pre/PrimeApps.Admin.zip?_=$(date +%s)"}

# Set versioned download links
if [ "$version" != "latest" ] ; then
    fileSetup=${PRIMEAPPS_FILE_SETUP:-"http://file.primeapps.io/pre/$version/setup.zip"}
    fileDatabase=${PRIMEAPPS_FILE_DATABASE:-"http://file.primeapps.io/pre/$version/database.zip"}
    fileAuth=${PRIMEAPPS_FILE_AUTH:-"http://file.primeapps.io/pre/$version/PrimeApps.Auth.zip"}
    fileApp=${PRIMEAPPS_FILE_APP:-"http://file.primeapps.io/pre/$version/PrimeApps.App.zip"}
    fileAdmin=${PRIMEAPPS_FILE_ADMIN:-"http://file.primeapps.io/pre/$version/PrimeApps.Admin.zip"}
fi

# Install dependencies - apt
echo -e "${GREEN}Installing Nginx${NC}"
apt -v &> /dev/null && apt install -y nginx

echo -e "${GREEN}Installing .NET Runtime 2.2${NC}"
apt -v &> /dev/null && ubuntu_version=$(lsb_release -r -s)
apt -v &> /dev/null && wget https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
apt -v &> /dev/null && dpkg -i packages-microsoft-prod.deb
apt -v &> /dev/null && apt install -y dotnet-runtime-2.2 unzip
which yum &> /dev/null && rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
which yum &> /dev/null && yum install -y dotnet-runtime-2.2 unzip

# Install dependencies - yum
echo -e "${GREEN}Installing Nginx${NC}"
which yum &> /dev/null && yum install -y epel-release
which yum &> /dev/null && yum install -y nginx
which yum &> /dev/null && sed -i $'/include /etc/nginx/conf.d/*.conf;/a \\\tclient_max_body_size 200m;\\\n\tproxy_buffer_size 16k;\\\n\tproxy_buffers 4 16k;\\\n\tserver_names_hash_bucket_size 64;\\\n\tinclude /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
which yum &> /dev/null && systemctl start nginx

# Download PRE
echo -e "${GREEN}Downloading PRE...${NC}"
mkdir pre
cd pre
echo -e "${GREEN}Downloading $fileSetup...${NC}"
curl $fileSetup -L --output setup.zip
echo -e "${GREEN}Downloading $fileDatabase...${NC}"
curl $fileDatabase -L --output database.zip
echo -e "${GREEN}Downloading $fileAuth...${NC}"
curl $fileAuth -L --output PrimeApps.Auth.zip
echo -e "${GREEN}Downloading $fileApp...${NC}"
curl $fileApp -L --output PrimeApps.App.zip
echo -e "${GREEN}Downloading $fileAdmin...${NC}"
curl $fileAdmin -L --output PrimeApps.Admin.zip

# Unzip PRE
echo -e "${GREEN}Unzipping PRE...${NC}"
unzip setup.zip
unzip database.zip
unzip PrimeApps.App.zip -d PrimeApps.App
unzip PrimeApps.Auth.zip -d PrimeApps.Auth
unzip PrimeApps.Admin.zip -d PrimeApps.Admin

# Set file ownership
chown $user --recursive PrimeApps.App
chown $user --recursive PrimeApps.Auth
chown $user --recursive PrimeApps.Admin

# Install PRE
echo -e "${GREEN}Installing PRE...${NC}"
cd "$basePathPre/setup"
./install.sh

# Set Postgres password
echo -e "${GREEN}Updating Postgres settings...${NC}"
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
systemctl daemon-reload
systemctl start postgres-pre.service

# Set Redis password
cd "$basePathPre/data/redis_pre"
systemctl stop redis-pre.service
sed -i "s/# requirepass foobared/requirepass ${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" redis.conf
sed -i "s/dir ./\\dir ${basePathPreRedisEscape}/g" redis.conf

systemctl daemon-reload
systemctl start redis-pre.service

# Set Minio access and secret keys
cd "$basePathPre/programs/minio"
systemctl stop minio-pre.service
storageSecretKeyEscape="${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}" # escape slash
sleep 3 # Sleep 3 seconds to stop Minio service
sed -i "s/MINIO_ACCESS_KEY/MINIO_ACCESS_KEY_OLD/g" /etc/systemd/system/minio-pre.service
sed -i "s/MINIO_SECRET_KEY/MINIO_SECRET_KEY_OLD/g" /etc/systemd/system/minio-pre.service
sed -i $"/storage-secret-key/aEnvironment=MINIO_ACCESS_KEY=$PRIMEAPPS_STORAGE_ACCESSKEY" /etc/systemd/system/minio-pre.service
sed -i $"/MINIO_ACCESS_KEY/aEnvironment=MINIO_SECRET_KEY=$PRIMEAPPS_STORAGE_SECRETKEY" /etc/systemd/system/minio-pre.service
systemctl daemon-reload
systemctl start minio-pre.service

# Create primeapps-auth service
echo -e "${GREEN}Creating primeapps-auth service...${NC}"
cp "$basePath/service/primeapps-auth.service" primeapps-auth.service
sed -i "s/{{USER}}/$user/g" primeapps-auth.service
sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-auth.service
sed -i "s/{{URL_SCHEME}}/${urlScheme//\//\\/}/g" primeapps-auth.service
sed -i "s/{{PORT_AUTH}}/$PRIMEAPPS_PORT_AUTH/g" primeapps-auth.service
sed -i "s/{{PASSWORD_DATABASE}}/${PRIMEAPPS_PASSWORD_DATABASE//\//\\/}/g" primeapps-auth.service
sed -i "s/{{PASSWORD_CACHE}}/${PRIMEAPPS_PASSWORD_CACHE//\//\\/}/g" primeapps-auth.service
sed -i "s/{{DOMAIN_AUTH}}/$PRIMEAPPS_DOMAIN_AUTH/g" primeapps-auth.service
sed -i "s/{{DOMAIN_STORAGE}}/$PRIMEAPPS_DOMAIN_STORAGE/g" primeapps-auth.service
sed -i "s/{{STORAGE_ACCESSKEY}}/${PRIMEAPPS_STORAGE_ACCESSKEY//\//\\/}/g" primeapps-auth.service
sed -i "s/{{STORAGE_SECRETKEY}}/${PRIMEAPPS_STORAGE_SECRETKEY//\//\\/}/g" primeapps-auth.service
sed -i "s/{{HTTPS_REDIRECTION}}/$PRIMEAPPS_SSL_USE/g" primeapps-auth.service
sed -i "s/{{PROXY_USE}}/$PRIMEAPPS_PROXY_USE/g" primeapps-auth.service
sed -i "s/{{PROXY_URL}}/${PRIMEAPPS_PROXY_URL//\//\\/}/g" primeapps-auth.service
sed -i "s/{{PROXY_VALIDATE_CERTIFICATE}}/$PRIMEAPPS_PROXY_VALIDATE_CERTIFICATE/g" primeapps-auth.service
sed -i "s/{{SENTRY_DSN_AUTH}}/${PRIMEAPPS_SENTRY_DSN_AUTH//\//\\/}/g" primeapps-auth.service

cp primeapps-auth.service /etc/systemd/system/primeapps-auth.service

systemctl start primeapps-auth.service
systemctl enable primeapps-auth.service

# Create primeapps-app service
echo -e "${GREEN}Creating primeapps-app service...${NC}"
cp "$basePath/service/primeapps-app.service" primeapps-app.service
sed -i "s/{{USER}}/$user/g" primeapps-app.service
sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-app.service
sed -i "s/{{URL_SCHEME}}/${urlScheme//\//\\/}/g" primeapps-app.service
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
sed -i "s/{{ENVIRONMENT}}/$PRIMEAPPS_ENVIRONMENT/g" primeapps-app.service
sed -i "s/{{GOOGLEMAPS_APIKEY}}/${PRIMEAPPS_GOOGLEMAPS_APIKEY//\//\\/}/g" primeapps-app.service
sed -i "s/{{ASPOSE_LICENCE}}/${PRIMEAPPS_ASPOSE_LICENCE//\//\\/}/g" primeapps-app.service
sed -i "s/{{PROXY_USE}}/$PRIMEAPPS_PROXY_USE/g" primeapps-app.service
sed -i "s/{{PROXY_URL}}/${PRIMEAPPS_PROXY_URL//\//\\/}/g" primeapps-app.service
sed -i "s/{{PROXY_VALIDATE_CERTIFICATE}}/$PRIMEAPPS_PROXY_VALIDATE_CERTIFICATE/g" primeapps-app.service
sed -i "s/{{SENTRY_DSN_APP}}/${PRIMEAPPS_SENTRY_DSN_APP//\//\\/}/g" primeapps-app.service

cp primeapps-app.service /etc/systemd/system/primeapps-app.service

systemctl start primeapps-app.service
systemctl enable primeapps-app.service

# Create primeapps-admin service
echo -e "${GREEN}Creating primeapps-admin service...${NC}"
cp "$basePath/service/primeapps-admin.service" primeapps-admin.service
sed -i "s/{{USER}}/$user/g" primeapps-admin.service
sed -i "s/{{PRE_ROOT}}/$basePathPreEscape/g" primeapps-admin.service
sed -i "s/{{URL_SCHEME}}/${urlScheme//\//\\/}/g" primeapps-admin.service
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
sed -i "s/{{PROXY_USE}}/$PRIMEAPPS_PROXY_USE/g" primeapps-admin.service
sed -i "s/{{PROXY_URL}}/${PRIMEAPPS_PROXY_URL//\//\\/}/g" primeapps-admin.service
sed -i "s/{{PROXY_VALIDATE_CERTIFICATE}}/$PRIMEAPPS_PROXY_VALIDATE_CERTIFICATE/g" primeapps-admin.service
sed -i "s/{{SENTRY_DSN_ADMIN}}/${PRIMEAPPS_SENTRY_DSN_ADMIN//\//\\/}/g" primeapps-admin.service

cp primeapps-admin.service /etc/systemd/system/primeapps-admin.service

systemctl start primeapps-admin.service
systemctl enable primeapps-admin.service

# Create Nginx configurations for PrimeApps
echo -e "${GREEN}Creating Nginx configurations...${NC}"

# TODO: If PRIMEAPPS_SSL_CERTIFICATE and PRIMEAPPS_SSL_CERTIFICATEKEY is not empty, replace ssl_certificate and ssl_certificate_key in $basePath/nginx.conf files

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_AUTH
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_AUTH/g" $PRIMEAPPS_DOMAIN_AUTH
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_AUTH/g" $PRIMEAPPS_DOMAIN_AUTH
cp $PRIMEAPPS_DOMAIN_AUTH /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_AUTH
ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_AUTH /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_AUTH

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_APP
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_APP/g" $PRIMEAPPS_DOMAIN_APP
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_APP/g" $PRIMEAPPS_DOMAIN_APP
cp $PRIMEAPPS_DOMAIN_APP /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_APP
ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_APP /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_APP

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_ADMIN
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_ADMIN/g" $PRIMEAPPS_DOMAIN_ADMIN
sed -i "s/{{PORT}}/$PRIMEAPPS_PORT_ADMIN/g" $PRIMEAPPS_DOMAIN_ADMIN
cp $PRIMEAPPS_DOMAIN_ADMIN /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_ADMIN
ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_ADMIN /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_ADMIN

cp "$basePath/nginx.conf" $PRIMEAPPS_DOMAIN_STORAGE
sed -i "s/{{DOMAIN}}/$PRIMEAPPS_DOMAIN_STORAGE/g" $PRIMEAPPS_DOMAIN_STORAGE
sed -i "s/{{PORT}}/9004/g" $PRIMEAPPS_DOMAIN_STORAGE
cp $PRIMEAPPS_DOMAIN_STORAGE /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_STORAGE
ln -s /etc/nginx/sites-available/$PRIMEAPPS_DOMAIN_STORAGE /etc/nginx/sites-enabled/$PRIMEAPPS_DOMAIN_STORAGE

systemctl daemon-reload

# TODO: backup database with pgBackRest
if [ "$backupDatabase" = "true" ] ; then
    echo -e "${GREEN}Creating database backup...${NC}"
fi

# Save version
cd $basePath
[[ -f "$basePathPre/setup/.version" ]] && cp "$basePathPre/setup/.version" .version

echo -e "${CYAN}Completed${NC}"