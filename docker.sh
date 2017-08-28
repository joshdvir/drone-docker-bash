#!/bin/bash

if [ -z ${PLUGIN_DRY_RUN} ]; then
  PLUGIN_DRY_RUN=false
fi

if [ ! -z ${PLUGIN_KEEP} ]; then
  keep=false
else
  keep=true
fi

if [ -z ${DRONE_COMMIT_SHA} ]; then
  DRONE_COMMIT_SHA="00000000"
fi


# Login env's
if [ -z ${PLUGIN_REGISTRY} ]; then
  echo "missing registry"
  exit 1
fi

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

# Login to Registry
/usr/local/bin/docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD $login_envs $PLUGIN_REGISTRY

# Docker build image
/usr/local/bin/docker build -t $PLUGIN_REPO:$DRONE_COMMIT_SHA -f $PLUGIN_DOCKERFILE $build_envs $PLUGIN_CONTEXT

IFS=',' read -r -a tags <<< "$PLUGIN_TAGS"
for tag in "${tags[@]}"
do
  /usr/local/bin/docker tag $PLUGIN_REPO:$DRONE_COMMIT_SHA $PLUGIN_REPO:$tag
  if [ "$PLUGIN_DRY_RUN" != true ] ; then
    # Docker push
    /usr/local/bin/docker push $PLUGIN_REPO:$tag
  fi
done

if [ "$keep" = true ] ; then
  /usr/local/bin/docker rmi $(/usr/local/bin/docker images -f reference=${PLUGIN_REPO}:* -q | sed 1,${PLUGIN_KEEP}d) | exit 0
fi