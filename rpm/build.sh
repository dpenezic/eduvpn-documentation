#!/bin/sh

PACKAGE_NAME=${1}
GITHUB_USER=${2}
GITHUB_NAME=${3}
VERSION=${4}

# download tarball
curl -s -L -o $HOME/rpmbuild/SOURCES/${VERSION}.tar.gz https://github.com/${GITHUB_USER}/${GITHUB_NAME}/archive/${VERSION}.tar.gz

# copy spec and sources to right location
(
    cd ${HOME}/rpmbuild/SOURCES/
    tar -xzf ${VERSION}.tar.gz
    cp ${GITHUB_NAME}-${VERSION}/rpm/* .
    mv ${PACKAGE_NAME}.spec ${HOME}/rpmbuild/SPECS/
    rm -rf ${GITHUB_NAME}-${VERSION}
)

# build package
(
    cd ${HOME}/rpmbuild/SPECS/
    rpmbuild -bs ${PACKAGE_NAME}.spec
)
