#!/bin/bash
set -e

if [ -z ${PLUGIN_DRY_RUN} ]; then
  PLUGIN_DRY_RUN=false
fi

if [ -z ${PLUGIN_KEEP} ]; then
  keep=false
else
  keep=true
fi

if [ -z ${DRONE_COMMIT_SHA} ]; then
  DRONE_COMMIT_SHA="00000000"
fi

if [ -z ${PLUGIN_NO_CACHE} ]; then
  PLUGIN_NO_CACHE=false
fi


# Login env's
# if [ -z ${PLUGIN_REGISTRY} ]; then
#   echo "missing registry"
#   exit 1
# fi

if [ -z ${DOCKER_USERNAME} ]; then
  echo "missing username"
  exit 1
fi

if [ -z ${DOCKER_PASSWORD} ]; then
  echo "missing password"
  exit 1
fi

login_envs=""
if [ ! -z ${DOCKER_EMAIL} ]; then
  login_envs="$login_envs -e $DOCKER_EMAIL"
fi


# Deamon env's
if [ -z ${PLUGIN_STORAGE_PATH} ]; then
  PLUGIN_STORAGE_PATH="/var/lib/docker"
fi

deamon_envs="-g $PLUGIN_STORAGE_PATH"
if [ ! -z ${PLUGIN_MIRROR} ]; then
  deamon_envs="$deamon_envs --registry-mirror $PLUGIN_MIRROR"
fi

if [ ! -z ${PLUGIN_STORAGE_DRIVER} ]; then
  deamon_envs="$deamon_envs -s $PLUGIN_STORAGE_DRIVER"
fi

if [ ! -z ${PLUGIN_BIP} ]; then
  deamon_envs="$deamon_envs --bip $PLUGIN_BIP"
fi

if [ ! -z ${PLUGIN_MTU} ]; then
  deamon_envs="$deamon_envs --mtu $PLUGIN_MTU"
fi

if [ ! -z ${PLUGIN_CUSTOM_DNS} ]; then
  deamon_envs="$deamon_envs --dns $PLUGIN_CUSTOM_DNS"
fi

if [ ! -z ${PLUGIN_CUSTOM_DNS_SEARCH} ]; then
  deamon_envs="$deamon_envs --dns-search $PLUGIN_CUSTOM_DNS_SEARCH"
fi

if [ ! -z ${PLUGIN_INSECURE} ]; then
  deamon_envs="$deamon_envs --insecure-registry $PLUGIN_INSECURE"
fi

if [ ! -z ${PLUGIN_IPV6} ]; then
  deamon_envs="$deamon_envs --ipv6 $PLUGIN_IPV6"
fi

if [ ! -z ${PLUGIN_EXPERIMENTAL} ]; then
  deamon_envs="$deamon_envs --experimental $PLUGIN_EXPERIMENTAL"
fi

if [ ! -z ${PLUGIN_DAEMON_OFF} ]; then
  PLUGIN_DAEMON_OFF=false
fi


# Build env's
if [ -z ${PLUGIN_DOCKERFILE} ]; then
  PLUGIN_DOCKERFILE="Dockerfile"
fi

if [ -z ${PLUGIN_CONTEXT} ]; then
  PLUGIN_CONTEXT="."
fi

if [ -z ${PLUGIN_TAGS} ]; then
  PLUGIN_TAGS="latest"
fi

build_envs=""
if [ ! -z ${PLUGIN_BUILD_ARGS} ]; then
  build_envs="$build_envs --build-arg $PLUGIN_BUILD_ARGS"
fi

if [ ! -z ${PLUGIN_SQUASH} ]; then
  build_envs="$build_envs --squash"
fi

if [ ! -z ${PLUGIN_PULL_IMAGE} ]; then
  build_envs="$build_envs --pull=true"
fi

if [ ! -z ${PLUGIN_COMPRESS} ]; then
  build_envs="$build_envs --compress"
fi

if [ ! -z ${PLUGIN_NO_CACHE} ]; then
  build_envs="$build_envs --no-cache"
fi

if [ -z ${PLUGIN_REPO} ]; then
  echo "missing repo"
  exit 1
fi


# Info
/usr/local/bin/docker version
/usr/local/bin/docker info

# Deamon
if [ "$PLUGIN_DAEMON_OFF" != true ] ; then
  /usr/local/bin/dockerd $deamon_envs &
fi

# timestamp=$(date +%s)
timestamp=$(cat $PLUGIN_DOCKERFILE | md5sum | awk '{print $1}')

# Login to Registry
/usr/local/bin/docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $login_envs $PLUGIN_REGISTRY

# Docker build image
/usr/local/bin/docker build -t $PLUGIN_REPO:$DRONE_COMMIT_SHA-$timestamp -f $PLUGIN_DOCKERFILE $build_envs $PLUGIN_CONTEXT

# If TWISTLOCK_USER and TWISTLOCK_PASSWORD is set, then download twistlock cli and scan for vulnerabilities in the image
if [[ ! -z "${TWISTLOCK_USER}" && ! -z "${TWISTLOCK_PASSWORD}" && ! -z "${PRISMA_CONSOLE_URL}" ]]; then
    echo "[INFO]: Getting Auth token for $TWISTLOCK_USER"
    token=$(curl -s -H "Content-Type: application/json" -d "{\"username\":\"$TWISTLOCK_USER\", \"password\":\"$TWISTLOCK_PASSWORD\"}" "$PRISMA_CONSOLE_URL/api/v1/authenticate")
    token=$(echo "$token" | jq -r ".token")
    echo "[INFO]: Downloading twistcli tool from $PRISMA_CONSOLE_URL"
    curl -s -L -k --header "authorization: Bearer $token" "$PRISMA_CONSOLE_URL/api/v1/util/twistcli" -o /bin/twistcli
    chmod +x /bin/twistcli
    /bin/twistcli images scan "$PLUGIN_REPO:$DRONE_COMMIT_SHA-$timestamp" --address "$PRISMA_CONSOLE_URL" --details
    rm -f /bin/twistcli
else
    echo "==========================================================================================="
    echo "[WARN]: Image $PLUGIN_REPO:$DRONE_COMMIT_SHA-$timestamp is not scanned for vulnerabilities."
    echo "[WARN]:    Set TWISTLOCK_USER, TWISTLOCK_PASSWORD, and PRISMA_CONSOLE_URL env varaibles in "
    echo "[WARN]:    build secrets settings to enable this scan."
    echo "==========================================================================================="
fi

IFS=',' read -r -a tags <<< "$PLUGIN_TAGS"
for tag in "${tags[@]}"
do
  echo "docker tag $PLUGIN_REPO:$DRONE_COMMIT_SHA-$timestamp $PLUGIN_REPO:$tag"
  /usr/local/bin/docker tag $PLUGIN_REPO:$DRONE_COMMIT_SHA-$timestamp $PLUGIN_REPO:$tag
  if [ "$PLUGIN_DRY_RUN" != true ] ; then
    # Docker push
    echo "docker push $PLUGIN_REPO:$tag"
    /usr/local/bin/docker push $PLUGIN_REPO:$tag
  fi
done

/usr/local/bin/docker rmi $PLUGIN_REPO:$DRONE_COMMIT_SHA-$timestamp

if [ "$keep" = true ] ; then
  echo "docker rmi $(docker images -f reference=${PLUGIN_REPO}:* -q | sed 1,${PLUGIN_KEEP}d)"
  /usr/local/bin/docker rmi $(/usr/local/bin/docker images -f reference=${PLUGIN_REPO}:* -q | sed 1,${PLUGIN_KEEP}d) | exit 0
fi

echo "docker rmi -f $(docker images | grep '${PLUGIN_REPO}' | grep '<none>' | awk '{print $3}')"
images=($(/usr/local/bin/docker images | grep '${PLUGIN_REPO}' | grep '<none>' | awk '{print $3}'))
for image in "${images[@]}"
do
  /usr/local/bin/docker rmi -f $image
done
echo "docker rmi $(/usr/local/bin/docker images -a --filter dangling=true -q)"
images=($(/usr/local/bin/docker images -a --filter dangling=true -q))
for image in "${images[@]}"
do
  /usr/local/bin/docker rmi -f $image
done
echo "docker system prune -f"
/usr/local/bin/docker system prune -f | exit 0
