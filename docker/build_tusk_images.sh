#!/usr/bin/env bash
#
# Assumes you're logged into Docker's registry and GitHub's registry
#
# build_images.sh [big | small]
#
# export MS_SKIP_PUSH="yes" to skip push to Docker and GitHub
# 

PROJECT_ROOT="/home/mshafae/github/tusk/docker"
RELEASES="22-jammy 24-noble 26-resolute"
ALPINE_RELEASES="3"
PROJECT="tusk"

# abort () {
#     >&2 echo "An error occurred. Exiting."
#     exit 1
# }

# trap 'abort' 0

# set -e

usage () {
    echo "build_images.sh [big|small|alpine]"
    echo "Will build [big|small|alpine] images and push to Docker and GH registry."
    echo "Assumes you're logged into Docker and GitHub."
}

test_docker_image () {
    _TARGET=$1
    docker buildx build --build-arg MS_GITHUB_PAT=${MS_GITHUB_PAT} --target test --tag test-${_TARGET} --file ${_TARGET}.Dockerfile . || exit 1
}

build_docker_image () {
    # Warning: Don't echo anything for debugging because the ID is 
    # being returned as an echo statement at the end.
    _TARGET=$1
    _ID=$(docker buildx build --quiet --build-arg MS_GITHUB_PAT=${MS_GITHUB_PAT} --target final --tag ${_TARGET} --file ${_TARGET}.Dockerfile .)
    if [ $_ID ]; then
        echo "$_ID"
    else
        echo "-1"
    fi
}

push_docker_image () {
    _TARGET=$1
    _ID=$2
    _DATE=$(date "+%Y%m%d%H%M")
    echo "push_docker_image"
    echo "${_TARGET} ${_ID} ${_DATE}"
    docker tag ${_ID} mshafae/${_TARGET}:${_DATE} || \
        echo "Failed docker tag ${_ID} mshafae/${_TARGET}:${_DATE}"
    docker tag ${_ID} mshafae/${_TARGET}:latest || \
        echo "Failed docker tag ${_ID} mshafae/${_TARGET}:latest"

    docker push mshafae/${_TARGET}:${_DATE} || \
        echo "Failed docker push mshafae/${_TARGET}:${_DATE}"
    docker push mshafae/${_TARGET}:latest || \
        echo "Failed docker push mshafae/${_TARGET}:latest"
}

# Not Used - just make sure you're logged in before running.
# ghcr_login () {
#     _USERNAME=$1
#     echo ${MS_GITHUB_PAT} | docker login ghcr.io -u ${_USERNAME} --password-stdin
# }

push_ghcr_image () {
    _TARGET=$1
    _ID=$2
    _DATE=$3
    echo "push_ghcr_image"
    echo "${_TARGET} ${_ID} ${_DATE}"
    docker tag ${_ID} ghcr.io/mshafae/${_TARGET}:${_DATE} || \
        echo "Failed docker tag ${_ID} ghcr.io/mshafae/${_TARGET}:${_DATE}"
    docker tag ${_ID} ghcr.io/mshafae/${_TARGET}:latest || \
        echo "Failed docker tag ${_ID} ghcr.io/mshafae/${_TARGET}:latest"

    docker push ghcr.io/mshafae/${_TARGET}:${_DATE} || \
        echo "Failed docker push ghcr.io/mshafae/${_TARGET}:${_DATE}"
    docker push ghcr.io/mshafae/${_TARGET}:latest || \
        echo "Failed docker push ghcr.io/mshafae/${_TARGET}:latest"
}

get_latest_ubuntu_tag () {
    RELEASE=$(echo $1 | cut -f 2 -d\-)
    wget -q -O - "https://hub.docker.com/v2/namespaces/library/repositories/ubuntu/tags?page_size=100" | grep -o '"name": *"[^"]*' | grep -oP "${RELEASE}-\d{8}" | sort -r | head -1
}

get_latest_mshafae_tag () {
    IMAGE=$1
    wget -q -O - "https://hub.docker.com/v2/namespaces/mshafae/repositories/${IMAGE}/tags?page_size=100" | grep -o '"name": *"[^"]*' | grep -oP "\d{12}" | sort -r | head -1
}

main () {
    # Not used - assumes you're logged into Docker and GitHub
    # if [ "${MS_GITHUB_PAT}x" = "x" ]; then
    #     echo "You need to set MS_GITHUB_PAT with your GH PAT to continue."
    #     exit 1
    # fi
    LONGOPTS=cron,dryrun,notest
    OPTIONS=c,n,x
    PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
    eval set -- "$PARSED"
    CRON="no"
    DRYRUN="no"
    NOTEST="no"
    while true; do
        case "$1" in
            -c|--cron)
                CRON="yes"
                shift
                ;;
            -n|--dryrun)
                DRYRUN="yes"
                shift
                ;;
            -x|--notest)
                NOTEST="yes"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Programming error"
                exit 1
                ;;
        esac
    done


    if [ $# -lt 1 ]; then
        echo "Not enough arguments. Specify big, small, or alpine."
        echo $#
        usage
        exit 1
    fi

    if [ -z "${MS_GITHUB_PAT}" ]; then
        PATFILE="/home/mshafae/.gh_automation"
        if [ -r $PATFILE ]; then
            echo "Using automation PAT."
            source $PATFILE
        else
            echo "Must have GitHub PAT set in MS_GITHUB_PAT."
            usage
            exit 1
        fi
    fi
    
    if [ -d ${PROJECT_ROOT} ]; then
        pushd ${PROJECT_ROOT} >& /dev/null
    else
        echo "Missing ${PROJECT_ROOT}"
        exit 1
    fi

    SIZE=$1
    if [ "x${SIZE}" != "xbig" -a "x${SIZE}" != "xsmall" -a "x${SIZE}" != "xalpine" ]; then
        usage
        exit 1
    fi

    if [ "x${SIZE}" = "xalpine" ]; then
        RELEASES=${ALPINE_RELEASES}
    fi

    DATE=$(date "+%Y%m%d%H%M")

    for REL in ${RELEASES}; do
        TARGET="${REL}-${SIZE}-${PROJECT}"
        echo "Starting to work on ${TARGET}"

        #build_docker_image ${REL} ${CURRENTTARGET} ${DATE} &
        
        if [ ! -r ${TARGET}.Dockerfile ]; then
            echo "Skipping ${TARGET}, no Dockerfile."
            continue
        fi

        if [ "x"${CRON} = "xyes" ]; then
            MS_TAG=$(get_latest_mshafae_tag ${TARGET})
            UBUNTU_TAG=$(get_latest_ubuntu_tag ${REL})
            UBUNTU_DATE=$(echo ${UBUNTU_TAG} | cut -f 2 -d\-)
            # Remove last four characters
            MS_SECS=$(date -d ${MS_TAG::-4} +%s)
            UBUNTU_SECS=$(date -d ${UBUNTU_DATE} +%s)
            if [ ${UBUNTU_SECS} -lt ${MS_SECS} ]; then
                echo "${UBUNTU_TAG} < ${MS_TAG}, skipping ${TARGET}"
                continue
            fi
        fi

        if [ "x"${NOTEST} = "xno" ]; then
            echo "Testing ${TARGET}"
            test_docker_image ${TARGET}
        fi
        
        echo "Building ${TARGET}"
        IMAGE_ID=$(build_docker_image ${TARGET})
        
        echo "Image ID ${IMAGE_ID}"
        if [ "x${IMAGE_ID}" = "x-1" ]; then
            echo "Failed building ${TARGET}. Continuing..."
            continue
        fi
        
        if [ "x"${MS_SKIP_PUSH} = "x" -a "x"${DRYRUN} = "xno" ]; then
            echo "Pushing image to Docker registry"
            push_docker_image ${TARGET} ${IMAGE_ID} ${DATE} || exit 1

            echo "Pushing image to GitHub registry"
            push_ghcr_image ${TARGET} ${IMAGE_ID} ${DATE} || exit 1
        fi

        if [ "x${IMAGE_ID}" != "x-1" ]; then
            echo
            echo "To run an interactive shell:"
            echo "docker run -it --user tuffy ${TARGET}"
            echo
        fi
    done
    popd >& /dev/null
    exit 0
}

main $*
