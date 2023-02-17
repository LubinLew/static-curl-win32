#!/usr/bin/bash
set -e
cd `dirname $0`
#####################################
WORKDIR="/curl"
IMAGE="ubuntu:latest"

# get latest version
function get_curl_version() {
  KEYWORD="Location: https://github.com/curl/curl/releases/tag/curl-"
  VERSION=$(curl -Isk 'https://github.com/curl/curl/releases/latest' | grep -i "${KEYWORD}" | sed "s#${KEYWORD}##i" | sed 's#_#.#g' | tr -d '\r')
  echo ${VERSION}
}

function get_current_latest() {
  KEYWORD="Location: https://github.com/LubinLew/static-curl-win32/releases/tag/"
  VERSION=$(curl -Isk 'https://github.com/LubinLew/static-curl-win32/releases/latest' | grep -i "${KEYWORD}" | sed "s#${KEYWORD}##i" | tr -d '\r')
  echo ${VERSION}
}

CURL_VERSION=$(get_curl_version)
LOCAL_VERSION=$(get_current_latest)

echo "== curl version: ${LOCAL_VERSION}/${CURL_VERSION}"
if [ "${CURL_VERSION}" == "${LOCAL_VERSION}" ] ; then
  echo "up to date"
  exit 0
fi

echo "update to ${CURL_VERSION}" > version.txt

docker pull ${IMAGE}
docker run --rm ${RUNENV} -v `pwd`/curl:${WORKDIR} -w ${WORKDIR} ${IMAGE} ${WORKDIR}/curl.sh 2>&1 | tee -a build.log

