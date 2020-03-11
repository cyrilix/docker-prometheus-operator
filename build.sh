#! /bin/bash

IMG_NAME=cyrilix/prometheus-operator
VERSION=0.37.0
MAJOR_VERSION=0.37
export DOCKER_CLI_EXPERIMENTAL=enabled
export DOCKER_USERNAME=cyrilix

set -e

init_qemu() {
    local qemu_url='https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1-1'

    docker run --rm --privileged multiarch/qemu-user-static:register --reset

    for target_arch in aarch64 arm x86_64; do
        wget -N "${qemu_url}/x86_64_qemu-${target_arch}-static.tar.gz";
        tar -xvf "x86_64_qemu-${target_arch}-static.tar.gz";
    done
}

fetch_sources() {
    if [[ ! -d  prometheus ]] ;
    then
        git clone https://github.com/coreos/prometheus-operator  ~/go/src/github.com/coreos/prometheus-operator
    fi
    set +e
    go get -u -d github.com/coreos/prometheus-operator
    go get -u k8s.io/apimachinery/pkg/apis/meta/v1
    go get -u k8s.io/api/core/v1
    go get -u github.com/go-kit/kit/log
    curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
    cd ~/go/src/github.com/coreos/prometheus-operator
    git checkout v${VERSION}
    dep ensure
    set -e
}

build_and_push_images() {
    local arch="$1"
    local dockerfile="$2"
    local img_name="$3"

    docker build --file "${dockerfile}" --tag "${img_name}:${arch}-latest" .
    docker tag "${img_name}:${arch}-latest" "${img_name}:${arch}-${VERSION}"
    docker tag "${img_name}:${arch}-latest" "${img_name}:${arch}-${MAJOR_VERSION}"
    docker push "${img_name}:${arch}-latest"
    docker push "${img_name}:${arch}-${VERSION}"
    docker push "${img_name}:${arch}-${MAJOR_VERSION}"
}


build_manifests() {
    docker -D manifest create "${IMG_NAME}:${VERSION}" "${IMG_NAME}:amd64-${VERSION}" "${IMG_NAME}:arm-${VERSION}" "${IMG_NAME}:arm64-${VERSION}"
    docker -D manifest annotate "${IMG_NAME}:${VERSION}" "${IMG_NAME}:arm-${VERSION}" --os=linux --arch=arm --variant=v6
    docker -D manifest annotate "${IMG_NAME}:${VERSION}" "${IMG_NAME}:arm64-${VERSION}" --os=linux --arch=arm64 --variant=v8
    docker -D manifest push "${IMG_NAME}:${VERSION}"

    docker -D manifest create "${IMG_NAME}:latest" "${IMG_NAME}:amd64-latest" "${IMG_NAME}:arm-latest" "${IMG_NAME}:arm64-latest"
    docker -D manifest annotate "${IMG_NAME}:latest" "${IMG_NAME}:arm-latest" --os=linux --arch=arm --variant=v6
    docker -D manifest annotate "${IMG_NAME}:latest" "${IMG_NAME}:arm64-latest" --os=linux --arch=arm64 --variant=v8
    docker -D manifest push "${IMG_NAME}:latest"

    docker -D manifest create "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:amd64-${MAJOR_VERSION}" "${IMG_NAME}:arm-${MAJOR_VERSION}" "${IMG_NAME}:arm64-${MAJOR_VERSION}"
    docker -D manifest annotate "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:arm-${MAJOR_VERSION}" --os=linux --arch=arm --variant=v6
    docker -D manifest annotate "${IMG_NAME}:${MAJOR_VERSION}" "${IMG_NAME}:arm64-${MAJOR_VERSION}" --os=linux --arch=arm64 --variant=v8
    docker -D manifest push "${IMG_NAME}:${MAJOR_VERSION}"
}

fetch_sources
init_qemu

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

rm -f operator
GOOS=linux GOARCH=amd64 make build prometheus-config-reloader
build_and_push_images amd64 ./Dockerfile "${IMG_NAME}"
build_and_push_images amd64 ./cmd/prometheus-config-reloader/Dockerfile "cyrilix/prometheus-config-reloader"

sed "s#FROM \+\(.*\)#FROM arm32v7/busybox\n\nCOPY qemu-arm-static /usr/bin/\n#" Dockerfile > Dockerfile.arm
rm -f operator
GOOS=linux GOARCH=arm GOARM=7 make build prometheus-config-reloader
build_and_push_images arm ./Dockerfile.arm "${IMG_NAME}"
build_and_push_images arm ./cmd/prometheus-config-reloader/Dockerfile "cyrilix/prometheus-config-reloader"

sed "s#FROM \+\(.*\)#FROM arm64v8/busybox\n\nCOPY qemu-arm-static /usr/bin/\n#" Dockerfile > Dockerfile.arm64
rm -f operator
GOOS=linux GOARCH=arm64 make build prometheus-config-reloader
build_and_push_images arm64 ./Dockerfile.arm64 "${IMG_NAME}"
build_and_push_images arm64 ./cmd/prometheus-config-reloader/Dockerfile "cyrilix/prometheus-config-reloader"

build_manifests "${IMG_NAME}"
build_manifests "cyrilix/prometheus-config-reloader"
