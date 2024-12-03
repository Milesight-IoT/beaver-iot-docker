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
BUILD_TARGET=${BUILD_TARGET:-"web,server,monolith"}
TARGET_PLATFORM=$TARGET_PLATFORM
DOCKER_REPO=${DOCKER_REPO:-"beaver-iot"}
BUILD_LATEST=${BUILD_LATEST:-true}
PRODUCTION_TAG=${PRODUCTION_TAG:-"latest"}
DOCKER_FILE=$DOCKER_FILE
DOCKER_BUILD_OPTION_PUSH=${DOCKER_BUILD_OPTION_PUSH:-false}
DOCKER_BUILD_OPTION_LOAD=${DOCKER_BUILD_OPTION_LOAD:-false}
DOCKER_BUILD_OPTION_REMOVE=${DOCKER_BUILD_OPTION_REMOVE:-false}
DOCKER_BUILD_OPTION_NO_CACHE=${DOCKER_BUILD_OPTION_NO_CACHE:-true}

# build args
SERVER_GIT_REPO_URL=$SERVER_GIT_REPO_URL
SERVER_GIT_BRANCH=$SERVER_GIT_BRANCH
WEB_GIT_REPO_URL=$WEB_GIT_REPO_URL
WEB_GIT_BRANCH=$WEB_GIT_BRANCH
BASE_SERVER_IMAGE=${BASE_SERVER_IMAGE:-"$DOCKER_REPO/server:$PRODUCTION_TAG"}
BASE_WEB_IMAGE=${BASE_WEB_IMAGE:-"$DOCKER_REPO/web:$PRODUCTION_TAG"}

user_args=()

function do_build() {
  PRODUCTION_NAME=$1
  echo "Building ${PRODUCTION_NAME}"

  args=()

  if [ "$DOCKER_BUILD_OPTION_PUSH" == "true" ]; then
    args+=(--push)
  else
    # push and load are mutually exclusive
    if [ "$DOCKER_BUILD_OPTION_LOAD" == "true" ]; then
      args+=(--load)
    fi
    args+=(-t "beaver-iot/${PRODUCTION_NAME}:${PRODUCTION_TAG}")
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
      args+=(-t "beaver-iot/${PRODUCTION_NAME}:latest")
    fi
  fi

  if [ -n "$TARGET_PLATFORM" ]; then
      args+=(--platform "${TARGET_PLATFORM}")
  fi

  docker buildx build \
    --network=host \
    --build-arg "SERVER_GIT_REPO_URL=${SERVER_GIT_REPO_URL}" \
    --build-arg "SERVER_GIT_BRANCH=${SERVER_GIT_BRANCH}" \
    --build-arg "WEB_GIT_REPO_URL=${WEB_GIT_REPO_URL}" \
    --build-arg "WEB_GIT_BRANCH=${WEB_GIT_BRANCH}" \
    --build-arg "BASE_SERVER_IMAGE=${BASE_SERVER_IMAGE}" \
    --build-arg "BASE_WEB_IMAGE=${BASE_WEB_IMAGE}" \
    -t "${DOCKER_REPO}/${PRODUCTION_NAME}:${PRODUCTION_TAG}" \
    -f "${DOCKER_FILE:-${CONTEXT_DIR}/${PRODUCTION_NAME}.dockerfile}" \
    "${args[@]}" \
    "${user_args[@]}" \
    "${CONTEXT_DIR}"
}

build() {
  echo "Build targets: ${BUILD_TARGET}"
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
  echo "  -h, --help                                          Show this help message."
  echo "  --build-target=<targets>                            Build targets, split by comma."
  echo "  --build-target <targets>                            Build targets, split by comma."
  echo "  --progress=plain                                    Show container output."
  echo "  --tag=<tag>                                         Add tag to image."
  echo "Environments:"
  echo "  BUILD_TARGET=[web|server|monolith]                  Build targets, split by comma."
  echo "  TARGET_PLATFORM=[linux/amd64|linux/arm64]           Target platform, split by comma. If provided, buildx buildkit is required."
  echo "  DOCKER_REPO=<registry>/beaver-iot                   Docker registry and repository."
  echo "  BUILD_LATEST=[true|false]                           Tag built image with 'latest'. Default set to 'true'."
  echo "  PRODUCTION_TAG=1.0.0                                Tag built image with specific tag."
  echo "  DOCKER_FILE=./all-in-one.dockerfile                 Dockerfile path. Don't change this unless you know what you are doing."
  echo "  DOCKER_BUILD_OPTION_PUSH=[true|false]               Push built image to registry."
  echo "  DOCKER_BUILD_OPTION_LOAD=[true|false]               Export built image to local containerd image store."
  echo "  DOCKER_BUILD_OPTION_REMOVE=[true|false]             Remove intermediate containers."
  echo "  DOCKER_BUILD_OPTION_NO_CACHE=[true|false]           Do not use cache. Default set to 'true' to ensure latest source code is always pulled from git."
  echo "  SERVER_GIT_REPO_URL=https://github.com/beaver-iot/server.git            Server git repository."
  echo "  SERVER_GIT_BRANCH=origin/master                                         Server git branch."
  echo "  WEB_GIT_REPO_URL=https://github.com/beaver-iot/web.git                  Web git repository."
  echo "  WEB_GIT_BRANCH=origin/master                                            Web git branch."
  echo "  BASE_SERVER_IMAGE                                                       Server base image for monolith image build."
  echo "  BASE_WEB_IMAGE                                                          Web base image for monolith image build."
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
      echo 0
      ;;
    build-target=*)
      val=${OPTARG#*=}
      opt=${OPTARG%=$val}
      BUILD_TARGET=$val
      ;;
    *=*)
      echo "Add docker build option: '--${OPTARG}'"
      user_args+=("--${OPTARG}")
      ;;
    *)
      val="${!OPTIND}"
      # if val starts with -, it's another option
      if [[ $val == -* || -z $val ]]; then
        echo "Add docker build option: '--${OPTARG}'"
        user_args+=("--${OPTARG}")
      else
        OPTIND=$(($OPTIND + 1))
        echo "Add docker build option: '--${OPTARG} ${val}'"
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
