#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  export_image_tags
#   DESCRIPTION:  Prepare the tags for the Docker images.
#     ARGUMENTS:
#             1:  The GitHub output variable name.
#             2:  The release name.
#             3:  The release tag.
#             4:  The tag suffix.
#----------------------------------------------------------------------------------------------------------------------
function export_image_tags() {
  local TAG_NAME="${1:?GitHub output variable name required}"
  local RELEASE_NAME="${2:-Latest Release}"
  local RELEASE_TAG="${3:-latest}"
  local TAG_SUFFIX="$4"

  IMAGE_TAGS=("${RELEASE_TAG}")

  if [[ "${RELEASE_NAME,,}" =~ lts$ ]]; then
    IMAGE_TAGS+=('lts')
  elif [[ "${RELEASE_NAME,,}" =~ sts$ ]]; then
    IMAGE_TAGS+=('sts')
  fi
  echo "Tags: ${IMAGE_TAGS[*]}"

  TAGS=""
  for _IMAGE_TAG in "${IMAGE_TAGS[@]}"; do
    DOCKER_IMAGE="${IMAGE_NAME}:${_IMAGE_TAG}"
    [[ -n "${TAG_SUFFIX}" ]] && DOCKER_IMAGE="${DOCKER_IMAGE}-${TAG_SUFFIX}"
    echo "Docker Image: ${DOCKER_IMAGE}"

    [[ -z "${TAGS}" ]] && TAGS="${DOCKER_IMAGE}" || TAGS="${TAGS},${DOCKER_IMAGE}"
    for registry in ${EXTRA_REGISTRIES}; do
      TAGS="${TAGS},${registry}/${DOCKER_IMAGE}"
    done
  done

  echo "Images list: ${TAGS}"

  echo "${TAG_NAME}=${TAGS}" >>"${GITHUB_OUTPUT}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  export_release_type_from_labels
#   DESCRIPTION:  Get the release type from the PR labels and export it as a GitHub output variable.
#     ARGUMENTS:
#             1:  The GitHub output variable name.
#             2:  The PR labels in JSON format.
#----------------------------------------------------------------------------------------------------------------------
function export_release_type_from_labels() {
  local OUTPUT_ID="${1:?GitHub output variable name required}"
  local LABELS="$2"

  local TYPE='latest'
  if echo "$LABELS" | jq -e 'any(.[]; .name == "sts")' > /dev/null; then
    TYPE='sts'
  elif echo "$LABELS" | jq -e 'any(.[]; .name == "lts")' > /dev/null; then
    TYPE='lts'
  fi

  echo "Release type: ${TYPE}"

  echo "${OUTPUT_ID}=${TYPE}" >> "${GITHUB_OUTPUT}"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  export_salt_version
#   DESCRIPTION:  Get the Salt version from the VERSION file and export it as a GitHub output variable.
#     ARGUMENTS:
#             1:  The GitHub output variable name.
#             2:  The release name.
#----------------------------------------------------------------------------------------------------------------------
function export_salt_version() {
  local OUTPUT_ID="${1:?GitHub output variable name required}"
  local RELEASE_NAME="${2:-Latest Release}"

  local VERSION_FILE="VERSION"
  if [[ "${RELEASE_NAME,,}" =~ lts$ ]]; then
    VERSION_FILE="VERSION_LTS"
  elif [[ "${RELEASE_NAME,,}" =~ sts$ ]]; then
    VERSION_FILE="VERSION_STS"
  fi

  local SALT_VERSION
  SALT_VERSION=$(cat ${VERSION_FILE})

  echo "Salt version: ${SALT_VERSION}"

  echo "${OUTPUT_ID}=${SALT_VERSION}" >> "${GITHUB_OUTPUT}"
}
