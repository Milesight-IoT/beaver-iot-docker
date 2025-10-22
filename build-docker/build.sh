#!/bin/bash
set -e

# context
WORK_DIR=$(pwd)
CONTEXT_DIR=$(
  cd "$(dirname "$0")"
  pwd
)

if [ -f "$CONTEXT_DIR/.env" ]; then
  source "$CONTEXT_DIR/.env"
fi

if [ -f "$WORK_DIR/.env" ]; then
  source "$WORK_DIR/.env"
fi

# config
BUILD_TARGET=${BUILD_TARGET:-"web,api,monolith"}
TARGET_PLATFORM=$TARGET_PLATFORM
DOCKER_REPO=${DOCKER_REPO:-"milesight"}
BUILD_LATEST=${BUILD_LATEST:-true}
PRODUCTION_TAG=${PRODUCTION_TAG:-"latest"}
DOCKER_FILE=$DOCKER_FILE
DOCKER_BUILD_OPTION_PUSH=${DOCKER_BUILD_OPTION_PUSH:-false}
DOCKER_BUILD_OPTION_LOAD=${DOCKER_BUILD_OPTION_LOAD:-false}
DOCKER_BUILD_OPTION_REMOVE=${DOCKER_BUILD_OPTION_REMOVE:-false}
DOCKER_BUILD_OPTION_NO_CACHE=${DOCKER_BUILD_OPTION_NO_CACHE:-true}

# build args
API_GIT_REPO_URL=${API_GIT_REPO_URL:-"https://github.com/milesight-iot/beaver-iot.git"}
API_GIT_BRANCH=${API_GIT_BRANCH:-"origin/release"}
API_MVN_PROFILE=${API_MVN_PROFILE:-"release"}
API_MVN_SNAPSHOT_REPO_ID=${API_MVN_SNAPSHOT_REPO_ID:-"central-portal-snapshots"}
API_MVN_SNAPSHOT_REPO_URL=${API_MVN_SNAPSHOT_REPO_URL:-"https://central.sonatype.com/repository/maven-snapshots/"}
BLUEPRINT_DEFAULT_LOCAL_ZIP_URL=$BLUEPRINT_DEFAULT_LOCAL_ZIP_URL
WEB_GIT_REPO_URL=${WEB_GIT_REPO_URL:-"https://github.com/milesight-iot/beaver-iot-web.git"}
WEB_GIT_BRANCH=${WEB_GIT_BRANCH:-"origin/release"}
BASE_API_IMAGE=${BASE_API_IMAGE:-"$DOCKER_REPO/beaver-iot-api:$PRODUCTION_TAG"}
BASE_WEB_IMAGE=${BASE_WEB_IMAGE:-"$DOCKER_REPO/beaver-iot-web:$PRODUCTION_TAG"}

user_args=()

function do_build() {

  # mapping alias to full name
  case $1 in
    monolith)
      PRODUCTION_NAME="beaver-iot"
      ;;
    web)
      PRODUCTION_NAME="beaver-iot-web"
      ;;
    api)
      PRODUCTION_NAME="beaver-iot-api"
      ;;
    *)
      PRODUCTION_NAME="$1"
  esac

  echo "Building ${PRODUCTION_NAME}"

  args=()

  if [ "$DOCKER_BUILD_OPTION_PUSH" == "true" ]; then
    args+=(--push)
  else
    # push and load are mutually exclusive
    if [ "$DOCKER_BUILD_OPTION_LOAD" == "true" ]; then
      args+=(--load)
    fi
    # add tag for local storage
    args+=(-t "milesight/${PRODUCTION_NAME}:${PRODUCTION_TAG}")
  fi

  if [ "$DOCKER_BUILD_OPTION_REMOVE" == "true" ]; then
    args+=(--rm)
  fi

  if [ "$DOCKER_BUILD_OPTION_NO_CACHE" == "true" ]; then
    args+=(--no-cache)
  fi

  if [ "$BUILD_LATEST" = "true" ] && [ "$PRODUCTION_TAG" != "latest" ]; then
    args+=(-t "${DOCKER_REPO}/${PRODUCTION_NAME}:latest")
    if [ "$DOCKER_BUILD_OPTION_PUSH" != "true" ]; then
      # add tag for local storage
      args+=(-t "milesight/${PRODUCTION_NAME}:latest")
    fi
  fi

  if [ -n "$TARGET_PLATFORM" ]; then
    args+=(--platform "${TARGET_PLATFORM}")
  fi

  if [ -n "$BLUEPRINT_DEFAULT_LOCAL_ZIP_URL" ]; then
    wget -O "$WORK_DIR/default_local_blueprint.zip" "$BLUEPRINT_DEFAULT_LOCAL_ZIP_URL"
  fi

  docker buildx build \
    --network=host \
    --build-arg "API_GIT_REPO_URL=${API_GIT_REPO_URL}" \
    --build-arg "API_GIT_BRANCH=${API_GIT_BRANCH}" \
    --build-arg "API_MVN_PROFILE=${API_MVN_PROFILE}" \
    --build-arg "API_MVN_SNAPSHOT_REPO_ID=${API_MVN_SNAPSHOT_REPO_ID}" \
    --build-arg "API_MVN_SNAPSHOT_REPO_URL=${API_MVN_SNAPSHOT_REPO_URL}" \
    --build-arg "WEB_GIT_REPO_URL=${WEB_GIT_REPO_URL}" \
    --build-arg "WEB_GIT_BRANCH=${WEB_GIT_BRANCH}" \
    --build-arg "BASE_API_IMAGE=${BASE_API_IMAGE}" \
    --build-arg "BASE_WEB_IMAGE=${BASE_WEB_IMAGE}" \
    -t "${DOCKER_REPO}/${PRODUCTION_NAME}:${PRODUCTION_TAG}" \
    -f "${DOCKER_FILE:-${CONTEXT_DIR}/${PRODUCTION_NAME}.dockerfile}" \
    "${args[@]}" \
    "${user_args[@]}" \
    "${CONTEXT_DIR}"
}

build() {
  if [ -n "$1" ]; then
    IFS=',' read -ra PRODUCTION_NAMES <<<"$1"
    for PRODUCTION_NAME in "${PRODUCTION_NAMES[@]}"; do
      do_build "${PRODUCTION_NAME}"
    done
  fi
}

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -h, --help                                                              Show this help message."
  echo "  --build-target=<targets>                                                Build targets, split by comma."
  echo "  --build-target <targets>                                                Build targets, split by comma."
  echo "  --progress=plain                                                        Show container output."
  echo "  --tag=<tag>                                                             Add tag to image."
  echo "Environments:"
  echo "  BUILD_TARGET=[beaver-iot-api|beaver-iot-web|beaver-iot]                 Build targets, split by comma."
  echo "  TARGET_PLATFORM=[linux/amd64|linux/arm64]                               Target platform, split by comma. If provided, buildx buildkit is required."
  echo "  DOCKER_REPO=<registry>/<repository>                                     Docker registry and repository."
  echo "  BUILD_LATEST=[true|false]                                               Tag built image with 'latest'. Default set to 'true'."
  echo "  PRODUCTION_TAG=1.0.0                                                    Tag built image with specific tag."
  echo "  DOCKER_BUILD_OPTION_PUSH=[true|false]                                   Push built image to registry."
  echo "  DOCKER_BUILD_OPTION_LOAD=[true|false]                                   Export built image to local containerd image store."
  echo "  DOCKER_BUILD_OPTION_REMOVE=[true|false]                                 Remove intermediate containers."
  echo "  DOCKER_BUILD_OPTION_NO_CACHE=[true|false]                               Do not use cache. Default set to 'true' to ensure latest source code is always pulled from git."
  echo "  API_GIT_REPO_URL=https://github.com/milesight-iot/beaver-iot.git        Git repository for Beaver IoT API."
  echo "  BLUEPRINT_DEFAULT_LOCAL_ZIP_URL                                         Default zip file url for Beaver IoT Blueprint."
  echo "  API_GIT_BRANCH=origin/release                                           Git branch for Beaver IoT API."
  echo "  WEB_GIT_REPO_URL=https://github.com/milesight-iot/beaver-iot-web.git    Git repository for Beaver IoT Web."
  echo "  WEB_GIT_BRANCH=origin/release                                           Git branch for Beaver IoT Web."
  exit 0
}

# getopts
while getopts ":h-:" optchar; do
  case "${optchar}" in
  h)
    show_help
    ;;
  -)
    case "${OPTARG}" in
    help)
      show_help
      ;;
    build-target)
      val="${!OPTIND}"
      OPTIND=$(($OPTIND + 1))
      BUILD_TARGET=$val
      ;;
    build-target=*)
      val=${OPTARG#*=}
      opt=${OPTARG%=$val}
      BUILD_TARGET=$val
      ;;
    *=*)
      user_args+=("--${OPTARG}")
      ;;
    *)
      val="${!OPTIND}"
      # if val starts with -, it's another option
      if [[ $val == -* || -z $val ]]; then
        user_args+=("--${OPTARG}")
      else
        OPTIND=$(($OPTIND + 1))
        user_args+=(--${OPTARG} ${val})
      fi
      ;;
    esac
    ;;
  *)
    echo "Unknown option: '-${OPTARG}'" >&2
    ;;
  esac
done

build "$BUILD_TARGET"
