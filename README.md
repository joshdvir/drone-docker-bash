# ECS deploy plugin for drone.io [https://hub.docker.com/r/joshdvir/drone-docker-bash/](https://hub.docker.com/r/joshdvir/drone-docker-bash/)

This plugin allows building a Docker image and pushing it to Registry

## Usage

```yaml
  pipeline:
    docker:
      image: joshdvir/drone-docker-bash
      repo: my-cluster
      username: my-service
      password: my-image:latest
```

Another example with optional variables

```yaml
  pipeline:
    docker:
      image: joshdvir/drone-docker-bash
      cluster: my-cluster
      service: my-service
      image_name: my-image:latest
      aws_region: us-east-1 # defaults to us-east-1
      timeout: "600" # defaults to 300 / 5 min
      max: "200" # defaults to 200
      min: "100" # defaults to 100
      aws_access_key_id: ewijdfmvbasciosvdfkl # optional, better to use as secret
      aws_secret_access_key: vdfklmnopenxasweiqokdvdfjeqwuioenajks # optional, better to use as secret
```

Another example to scan images for vulnerabilities
```yaml
  docker:
    image: docker.twistbioscience-staging.com/drone-docker-bash:latest
    pull: true
    registry: docker.twistbioscience-staging.com
    repo: docker.twistbioscience-staging.com/mes-clu
#     Set this environment variable if you want to scan but
#     not publish to docker registry
#     environment:
#       - PLUGIN_DRY_RUN=true
    tags:
      - "${DRONE_COMMIT:0:8}.${DRONE_BUILD_NUMBER}.${DRONE_COMMIT_BRANCH}"
    force_tag: true
    dockerfile: Dockerfile
    keep: 4
    secrets: [ docker_username, docker_password, docker_email, prisma_console_url, twistlock_user, twistlock_password ]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    when:
      branch: [master]
      event: push
```