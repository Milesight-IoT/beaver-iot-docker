# Beaver IoT Docker

[![Build Docker Image](https://github.com/Milesight-IoT/beaver-iot-docker/actions/workflows/run-build.yaml/badge.svg)](https://github.com/Milesight-IoT/beaver-iot-docker/actions/workflows/run-build.yaml)

## Requirements

- Docker: Version 20.10 or higher

## Deployment

Please refer to the [deployment documentation](https://www.milesight.com/beaver-iot/docs/dev-guides/deployment/)

## Build

### Preparations

Navigate to the `build-docker` directory and create a `.env` configuration file:

```shell
touch build-docker/.env
```

Edit the `.env` configuration file with the following content:

```dotenv
# Load the build result to `docker images`
DOCKER_BUILD_OPTION_LOAD=true
# Docker registry and repository
DOCKER_REGISTRY=milesight
# Image tag
PRODUCTION_TAG=latest
# Git repository URLs and branches
WEB_GIT_REPO_URL=https://github.com/Milesight-IoT/beaver-iot-web.git
WEB_GIT_BRANCH=origin/release
API_GIT_REPO_URL=https://github.com/Milesight-IoT/beaver-iot.git
API_GIT_BRANCH=origin/release
```

> The subsequent build steps will use the configurations in this file, whether you use build.sh or docker compose.

### Building via Bash Script

Execute the build script to commence the build process:

```shell
./build-docker/build.sh
```

If you need to build only specific images, you can specify them using the `--build-target` parameter:

```shell
./build-docker/build.sh --build-target=beaver-iot,beaver-iot-web
```

For additional configuration options, use the --help option:

```shell
./build-docker/build.sh --help
```

### Building via Docker Compose

If you don't have a Bash environment, you can build the images directly using the new version of Docker Compose:

```shell
cd build-docker && docker compose build --no-cache
```
