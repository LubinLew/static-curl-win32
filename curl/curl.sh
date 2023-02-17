#!/bin/bash
set -e
cd $(dirname $0)
############################################################
## log
TAG="CURL"
############################################################

# get latest version
function get_curl_version() {
  KEYWORD="Location: https://github.com/curl/curl/releases/tag/curl-"
  VERSION=$(curl -Isk 'https://github.com/curl/curl/releases/latest' | grep -i "${KEYWORD}" | sed "s#${KEYWORD}##i" | sed 's#_#.#g' | tr -d '\r')
  echo ${VERSION}
}

# gpg verify
function verify_curl_source() {
  VERSION=$1
  apt-get install -y gnupg gpg-agent > /dev/null

  echo "[${TAG}] downloading gpg public key ..."
  GPGKEY="https://daniel.haxx.se/mykey.asc"
  if [ ! -f mykey.asc ] ; then
    wget ${GPGKEY}
  fi

  echo "[${TAG}] verifying source ..."
  gpg --show-keys mykey.asc|grep '^ '|tr -d ' '|awk '{print $0":6:"}' > /tmp/ownertrust.txt
  gpg --import-ownertrust < /tmp/ownertrust.txt > /dev/null
  gpg --import mykey.asc  > /dev/null
  gpg --verify curl-${VERSION}.tar.bz2.asc curl-${VERSION}.tar.bz2
}

## download source
function get_curl_source() {
  VERSION=$1
  SOURCE="https://curl.se/download/curl-${VERSION}.tar.bz2"
  
  echo "[${TAG}] downloading source ..."
  if [ ! -f curl-${VERSION}.tar.bz2 ] ; then
    wget ${SOURCE}
  fi

  echo "[${TAG}] downloading signature file ..."
  if [ ! -f curl-${VERSION}.tar.bz2.asc ] ; then
    wget ${SOURCE}.asc
  fi
}

## build static
function build_curl_source() {
  VERSION=$1
  echo "[${TAG}] preparing for build ..."
  
  if [ ! -f release.md ] ; then
cat > release.md<<EOF
# static curl ${CURL_VERSION}
| Name | Arch | TLS Provider | TLSv1.0 | TLSv1.1 | TLSv1.2 | TLSv1.3 | sha256sum |
|------|------|--------------|---------|---------|---------|---------|-----------|
EOF
  chmod 777 release.md
  fi  
  
  # install compiler
  apt-get install -y mingw-w64 make > /dev/null

  ln -s /usr/bin/i686-w64-mingw32-gcc      /usr/local/bin/i686-cc
  ln -s /usr/bin/i686-w64-mingw32-gcc      /usr/local/bin/i686-gcc
  ln -s /usr/bin/i686-w64-mingw32-cpp      /usr/local/bin/i686-cpp
  ln -s /usr/bin/i686-w64-mingw32-ld       /usr/local/bin/i686-ld
  ln -s /usr/bin/i686-w64-mingw32-gcc-ar   /usr/local/bin/i686-ar
  ln -s /usr/bin/i686-w64-mingw32-windres  /usr/local/bin/i686-windres
  ln -s /usr/bin/i686-w64-mingw32-strip    /usr/local/bin/i686-strip

  ln -s /usr/bin/x86_64-w64-mingw32-gcc     /usr/local/bin/x86_64-cc
  ln -s /usr/bin/x86_64-w64-mingw32-gcc     /usr/local/bin/x86_64-gcc
  ln -s /usr/bin/x86_64-w64-mingw32-cpp     /usr/local/bin/x86_64-cpp
  ln -s /usr/bin/x86_64-w64-mingw32-ld      /usr/local/bin/x86_64-ld
  ln -s /usr/bin/x86_64-w64-mingw32-gcc-ar  /usr/local/bin/x86_64-ar
  ln -s /usr/bin/x86_64-w64-mingw32-windres /usr/local/bin/x86_64-windres
  ln -s /usr/bin/x86_64-w64-mingw32-strip   /usr/local/bin/x86_64-strip

  echo "[${TAG}] building source ..."
  rm -rf curl-${VERSION}
  tar xf curl-${VERSION}.tar.bz2
  cd     curl-${VERSION}

  export LDFLAGS="--static"

  ARCHS=("i686" "x86_64")
  for arch in ${ARCHS[@]} ; do
     make clean || true
    ./configure \
       --host ${arch} \
       --disable-shared \
       --enable-static \
       --enable-ipv6 \
       --enable-unix-sockets \
       --enable-tls-srp \
       --with-schannel \
       --with-zlib \
       --disable-ldap \
       --disable-dict \
       --disable-gopher \
       --disable-imap \
       --disable-smtp \
       --disable-rtsp \
       --disable-telnet \
       --disable-tftp \
       --disable-pop3 \
       --disable-mqtt \
       --disable-ftp \
       --disable-smb

    make -j`nproc`

    CURL="curl_${arch}_static.exe"
    cp -f src/curl.exe ../${CURL}.nonstrip
    cp -f src/curl.exe ../${CURL}
    ${arch}-strip -s   ../${CURL}

  SUM1=$(sha256sum ../${CURL}          | awk '{print $1}')
  SUM2=$(sha256sum ../${CURL}.nonstrip | awk '{print $1}')

cat >> release.md<<EOF
| ${CURL}          | ${arch} | schannel | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x: | ${SUM1} |
| ${CURL}.nonstrip | ${arch} | schannel | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :x: | ${SUM2} |
EOF
  done
}


############################################################
apt-get update -y > /dev/null
apt-get install -y curl wget bzip2 > /dev/null
 
if [ -z ${CURL_VERSION} ] ; then
  CURL_VERSION=$(get_curl_version)
fi
echo "[${TAG}] version=${CURL_VERSION}"

get_curl_source    ${CURL_VERSION}

verify_curl_source ${CURL_VERSION}

build_curl_source  ${CURL_VERSION}




