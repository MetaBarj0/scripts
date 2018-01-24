#!/bin/sh

# /!\ DO NOT EDIT THIS FILE
# It is part of the automated build system. Images can be customized following
# instructions in READMEs files. Moreover, you can get inspired by template
# files located in the share/image directory

set -e

checkArgument() {
  # need some functions...
  . ${DOCKER_LIB_DIRECTORY}/functions.sh

  local argument_error_message="$(
  cat << EOI
OK, you gave me some baadf00d. I only expect one argument, and this argument
must be a valid file path of a manifest file for a project that build a sexy
chicky big mama of docker image that is so fancy and so shiny it'll make you
happy for the rest of your life...unless you gave me some baadf00d like now...
Bye.
EOI
  )"
  
  # This script needs one argument: either
  #  - an absolute path to a manifest file
  #  - a relative path to a manifest file
  #  - a valid docker image name which can be found in the share/image directory
  if [ ! $# -eq 1 ]; then
    error "$argument_error_message"
    exit 1
  fi
  
  # try to resolve the manifest file path by:
  #  - appending it to the current user directory, useful if relative path is
  #    provided
  #  - testing directly the file path, useful if absolute path is provided
  local assumed_manifest_file_path="$1"
  if [ ! -f ${USER_DIRECTORY}/"$assumed_manifest_file_path" ] \
     && [ ! -f "$assumed_manifest_file_path" ]; then
    # not a file path, testing the image name
    assumed_manifest_file_path=${DOCKER_IMAGES_DIRECTORY}/"$1"/manifest
    if [ ! -f ${assumed_manifest_file_path} ]; then
      error "$argument_error_message"
      exit 1
    fi
  fi

  # OK, valid argument, exposing the manifest file absolute path
  MANIFEST_FILE_PATH=${assumed_manifest_file_path}
}

checkFoundationImages() {
  # first, verify if bootstrap has built all necessary foundation images, that
  # is metabarj0/manifest, metabarj0/gcc, metabarj0/make and
  # metabarj0/docker-cli
  local required_images="$(
  cat << EOI
metabarj0/manifest
metabarj0/gcc
metabarj0/make
metabarj0/docker-cli
EOI
  )"
  
  for i in $required_images; do
    id=$(docker image ls -q $i)
    if [ -z $id ]; then
      error 'Hmm...the mandatory image '$i' has not been found on your'
      error 'docker host...That is annoying! Make sure you have built and'
      error 'run the bootstrap project before attempting to build any'
      error 'further project.'
      exit 1
    fi
  done
}

setupDockerDirectories() {
  # current directory
  USER_DIRECTORY=$(pwd -P)

  # resolving important docker directories
  DOCKER_BIN_DIRECTORY=$(dirname $0)
  cd ${DOCKER_BIN_DIRECTORY}/..

  DOCKER_ROOT_DIRECTORY=$(pwd -P)
  DOCKER_LIB_DIRECTORY=${DOCKER_ROOT_DIRECTORY}/lib
  DOCKER_TMP_DIRECTORY=${DOCKER_ROOT_DIRECTORY}/tmp
  DOCKER_SHARE_DIRECTORY=${DOCKER_ROOT_DIRECTORY}/share
  DOCKER_IMAGES_DIRECTORY=${DOCKER_SHARE_DIRECTORY}/images

  # back to current directory
  cd $USER_DIRECTORY
}

increaseRecursiveLevel() {
  # does work even if the var is not set first
  export RECURSIVE_LEVEL=$(( RECURSIVE_LEVEL + 1 ))
}

decreaseRecursiveLevel() {
  # unset the var once 0 is reached
  export RECURSIVE_LEVEL=$(( RECURSIVE_LEVEL - 1 ))
  if [ $RECURSIVE_LEVEL -le 0 ]; then
    unset RECURSIVE_LEVEL
  fi
}

buildDependencies() {
  # any dependency build will increase the recursive level
  increaseRecursiveLevel

  # browse all dependencies
  for dep in $REQUIRES; do
    # first, check on the host if the image exists; if so, continue without
    # building it
    local repository=$(docker image ls -q "$dep")
    if [ ! -z "$repository" ]; then
      continue
    fi

    # no existing image found on the host, building it, the current directory
    # being the image staging directory
    local dependency_manifest=$(
      find . \
        -name manifest \
        -exec \
          grep -EH 'PROVIDES='$dep {} \; \
          | sed -r 's/^([^:]+):.+/\1/'
    )

    # about to trigger a recursive build in a subshell
    ( exec $0 "$dependency_manifest" )
  done

  # dependencies build done, decrease the recursive level, unsetting it if 0
  decreaseRecursiveLevel
}

fillStagingArea() {
  local image_directory=$(dirname $MANIFEST_FILE_PATH)

  # copy the project in the staging area
  cp -a $image_directory $DOCKER_TMP_DIRECTORY

  # copy necessary lib files in the project directory in the staging area
  local image_name=$(basename $image_directory)
  IMAGE_STAGING_DIRECTORY=${DOCKER_TMP_DIRECTORY}/$image_name

  cd $DOCKER_LIB_DIRECTORY

  cp \
    build-image.sh \
    build.sh \
    Dockerfile.build-image \
    exportPackageTo \
    functions.sh \
    importPackageFrom \
    $IMAGE_STAGING_DIRECTORY

  cd $USER_DIRECTORY
}

buildProject() {
  # source the content of the manifest file, that will initialize some useful 
  # variables
  . $MANIFEST_FILE_PATH

  # change directory to the image staging directory to work
  cd $IMAGE_STAGING_DIRECTORY

  # verify if any dependency has been built, avoiding an unnecessary manifest 
  # pull, this test is true if we are not in a recursive call
  if [ -z ${RECURSIVE_LEVEL+0} ]; then
    # background running of a manifest container
    local image_id=$(docker run --rm -d metabarj0/manifest)

    # update the manifest
    docker exec $image_id update
  
    # preparing manifest content to be copied on the host in the current
    # directory, then kill the running container
    docker cp $image_id:/docker.tar.bz2 .
    docker kill $image_id

    tar -xf docker.tar.bz2
    rm -f docker.tar.bz2
  fi

  # build all dependencies of this project first if there are
  if [ ! -z "$REQUIRES" ]; then
    buildDependencies "$@"
  fi
  
  # rely on some variables extracted from the manifest file that was parsed
  (
    exec \
      $(pwd -P)/build.sh \
      $PROVIDES \
      $(pwd -P) \
      "$EXTRA_DOCKERFILE_COMMANDS"
  )
  
  # cleanup if not in a recursive call
  if [ -z ${RECURSIVE_LEVEL+0} ] || [ $RECURSIVE_LEVEL -eq 0 ]; then
    rm -rf docker
  fi

  # return to the user directory
  cd $USER_DIRECTORY
}

cleanupStagingArea() {
  rm -rf $IMAGE_STAGING_DIRECTORY
}

# running the script, forwarding provided arguments
# first check for foundation images (provided by bootstrap)
# then, setup some important docker directories
# then check the provided argument that must be either :
#  - an absolute path to a manifest file
#  - a relative path to a manifest file
#  - the name of an image being present in the /share/images directory and being
#    a directory containing a valid image project with a manifest file
# then, fill the staging area for the current image build process
# finally, build the project

checkFoundationImages
setupDockerDirectories
checkArgument "$1"
fillStagingArea
buildProject "$@"
cleanupStagingArea
