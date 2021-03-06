#!/usr/bin/env bash
set -e
set -x

if [ -f "version" ]; then
  VERS=$(cat version | tr -d "\n")
fi

if [ -f "../version" ]; then
  VERS=$(cat ../version | tr -d "\n")
fi

if [ "${1}" != "" ]; then
  VERS=${1}
fi

sysname=$(uname)

stdlibname="libstdc++"
if [ "${sysname}" == "Darwin" ]; then
  stdlibname="libc++"
fi

if [ "${sysname}" == "Linux" ]; then
  CONAN_LOCAL=1 conan create . edwardstock/latest -s compiler.libcxx=${stdlibname}11 -s build_type=Debug --build=missing
  CONAN_LOCAL=1 conan create . edwardstock/latest -s compiler.libcxx=${stdlibname}11 -s build_type=Release --build=missing
fi

CONAN_LOCAL=1 conan create . edwardstock/latest -s compiler.libcxx=${stdlibname} -s build_type=Debug --build=missing
CONAN_LOCAL=1 conan create . edwardstock/latest -s compiler.libcxx=${stdlibname} -s build_type=Release --build=missing

if [ "${NOUPLOAD}" != "1" ]; then
  CONAN_LOCAL=1 conan upload toolbox/${VERS}@edwardstock/latest --all -r=edwardstock
fi
