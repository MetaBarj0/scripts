#!/bin/sh

# /!\ Do not edit this file, it is intended to help you to bootstrap your
# environment (docker host) and create the bare minimum stuff to play further
# with carrier's docker toys.

set -e

## get the directory architecture from the invoke point
## populate the tmp directory with bootstrap stuff
## populate the tmp directory with the necessary tooling
## ask the user for necessary variable with valid defaults values
## build and run the docker image responsible to bootstrap the system
## cleanup staging area

setupDirectories() {
  # could be anywhere
  USER_DIRECTORY="$(pwd -P)"

  local this_script_directory="$(dirname "$0")"

  # this script is located under bin/ directory, deducing /
  cd "$this_script_directory/.."
  DOCKER_ROOT_DIRECTORY="$(pwd -P)"

  # staging area used to build the bootstrap
  DOCKER_STAGING_AREA="$DOCKER_ROOT_DIRECTORY"/tmp

  # where to find utilities
  DOCKER_LIB_DIRECTORY="$DOCKER_ROOT_DIRECTORY"/lib

  # go back to the user directory
  cd "$USER_DIRECTORY"
}

fetchBootstrapInStagingArea() {
  local bootstrap_directory="$DOCKER_ROOT_DIRECTORY"/share/bootstrap

  cp -r "$bootstrap_directory" "$DOCKER_STAGING_AREA"
}

fetchLibInStagingArea() {

  cp "$DOCKER_LIB_DIRECTORY"/exportPackageTo \
     "$DOCKER_LIB_DIRECTORY"/importPackageFrom \
     "$DOCKER_LIB_DIRECTORY"/functions.sh \
     "$DOCKER_STAGING_AREA"/bootstrap
}

buildBootstrap() {
  cd "$DOCKER_STAGING_AREA"/bootstrap

  docker build --squash -t metabarj0/bootstrap .
  docker image prune -f

  cd $USER_DIRECTORY
}

runBootstrap() {
  # need some functions
  . "$DOCKER_STAGING_AREA"/bootstrap/functions.sh

  cat << EOI
Specify the version of GCC you want to build. Note that today, only 7.2.0 is
supported : [7.2.0]
EOI

  local gcc_version="$(readValueWithDefault '7.2.0')"

  cat << EOI
Specify the binutils version you want to build. Note that for GCC 7.2.0, 2.29
is a working version : [2.29]
EOI

  local binutils_version="$(readValueWithDefault '2.29')"

  cat << EOI
Specify the version of Kernel headers you want to use. Note that for GCC 7.2.0
the 4.14.3 version works perfectly well. Moreover, only version 4+ is
supported : [4.14.14]
EOI

  local kernel_version="$(readValueWithDefault '4.14.14')"

  cat << EOI
Specify the make version you want to use. Note that version 4.2 is
good : [4.2]
EOI

  local make_version="$(readValueWithDefault '4.2')"

  # run the bootstrap image
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e GCC_VERSION="$gcc_version" \
  -e BINUTILS_VERSION="$binutils_version" \
  -e KERNEL_VERSION="$kernel_version" \
  -e MAKE_VERSION="$make_version" \
  metabarj0/bootstrap
}

cleanupStagingArea() {

  rm -rf "$DOCKER_STAGING_AREA"/bootstrap
}

setupDirectories

fetchBootstrapInStagingArea
fetchLibInStagingArea

buildBootstrap
runBootstrap

cleanupStagingArea
