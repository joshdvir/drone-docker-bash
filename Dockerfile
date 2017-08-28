FROM docker:17.05-ce-dind

RUN apk add --update --no-cache \
    curl \
    jq \
    ca-certificates \
    bash

ADD docker.sh /bin/
ENTRYPOINT ["/usr/local/bin/dockerd-entrypoint.sh", "/bin/docker.sh"]
