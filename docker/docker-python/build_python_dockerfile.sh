#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -e

# Check Params
programname=$0

function usage {
    echo "usage: $programname [version] [path]"
    echo "  [version]  Mxnet Version to build"
    echo "  [path]     Path to MXNet repository (to run tests)"
    echo " "
    exit 1
}

if [ $# -le 1 ] || [ $# -ge 3 ]
then
    usage
    exit 1
fi

# Two params provided
echo "Building Docker Images for Apache MXNet (Incubating) v$1"
mxnet_version="${1}"
test_dir="${2}"

docker_build_image(){
    echo "Building docker image mxnet/python:${1}"
    docker build -t mxnet/python:${1} -f ${2} .
}

docker_tag_image(){
    docker tag mxnet/python:${1} mxnet/python:${2}
}

docker_test_image_cpu(){
    echo "Running tests on mxnet/python:${1}"
    docker run -v ${test_dir}:/mxnet mxnet/python:${1} bash -c "python /mxnet/docker/docker-python/test_mxnet.py ${mxnet_version}"
    docker run -v ${test_dir}:/mxnet mxnet/python:${1} bash -c "python /mxnet/tests/python/train/test_conv.py"
    docker run -v ${test_dir}:/mxnet mxnet/python:${1} bash -c "python /mxnet/example/image-classification/train_mnist.py"
}

docker_test_image_gpu(){
    echo "Running tests on mxnet/python:${1}"
    nvidia-docker run -v ${test_dir}:/mxnet mxnet/python:${1} bash -c "python /mxnet/docker/docker-python/test_mxnet.py ${mxnet_version}"
    nvidia-docker run -v ${test_dir}:/mxnet mxnet/python:${1} bash -c "python /mxnet/tests/python/train/test_conv.py --gpu"
    nvidia-docker run -v ${test_dir}:/mxnet mxnet/python:${1} bash -c "python /mxnet/example/image-classification/train_mnist.py --gpus 2"
}

docker_account_login(){
    docker login
}

docker_account_logout(){
    docker logout
}

docker_push_image(){
    docker push mxnet/python:${1}
}


# Build and Test dockerfiles - CPU
docker_build_image "${mxnet_version}_cpu" "Dockerfile.mxnet.python.cpu"
docker_test_image_cpu "${mxnet_version}_cpu"

docker_build_image "${mxnet_version}_cpu_mkl" "Dockerfile.mxnet.python.cpu.mkl"
docker_test_image_cpu "${mxnet_version}_cpu_mkl"

docker_tag_image "${mxnet_version}_cpu" "latest"
docker_test_image_cpu "latest"


#Build and Test dockerfiles - GPU
docker_build_image "${mxnet_version}_gpu_cu90" "Dockerfile.mxnet.python.gpu"
docker_test_image_gpu "${mxnet_version}_gpu_cu90"

docker_build_image "${mxnet_version}_gpu_cu90_mkl" "Dockerfile.mxnet.python.gpu.mkl"
docker_test_image_gpu "${mxnet_version}_gpu_cu90_mkl"

docker_tag_image "${mxnet_version}_gpu_cu90" "gpu"
docker_test_image_gpu "gpu"


# Push dockerfiles
echo "All images were successfully built. Now login to dockerhub and push images"
docker_account_login

docker_push_image "${mxnet_version}_cpu"
docker_push_image "${mxnet_version}_cpu_mkl"
docker_push_image "latest"
docker_push_image "${mxnet_version}_gpu_cu90"
docker_push_image "${mxnet_version}_gpu_cu90_mkl"
docker_push_image "gpu"

docker_account_logout