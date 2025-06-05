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
  local RELEASE_NAME="${2:-Latest release}"
  local RELEASE_TAG="${3:-latest}"
  local TAG_SUFFIX="$4"

  IMAGE_TAGS=("${RELEASE_TAG}")

  if [[ "${RELEASE_NAME,,}" =~ lts$ ]]; then
    IMAGE_TAGS+=('lts')
  elif [[ "${RELEASE_NAME,,}" =~ sts$ ]]; then
    IMAGE_TAGS+=('sts')
  fi
  echo "Tags: ${IMAGE_TAGS[@]}"

  for _IMAGE_TAG in "${IMAGE_TAGS[@]}"; do
    DOCKER_IMAGE="${IMAGE_NAME}:${_IMAGE_TAG}"
    [[ -n "${TAG_SUFFIX}" ]] && DOCKER_IMAGE="${DOCKER_IMAGE}-${TAG_SUFFIX}"
    echo "Docker Image: ${DOCKER_IMAGE}"

    TAGS="${DOCKER_IMAGE}"
    for registry in ${EXTRA_REGISTRIES}; do
      TAGS="${TAGS},${registry}/${DOCKER_IMAGE}"
    done
  done

  echo "Images list: ${TAGS}"

  echo "${TAG_NAME}=${TAGS}" >>"${GITHUB_OUTPUT}"
}
