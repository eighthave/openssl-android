#!/bin/bash
#
# This script imports new versions of OpenSSL (http://openssl.org/source) into the
# Android source tree.  To run, (1) fetch the appropriate tarball from the OpenSSL repository,
# (2) check the gpg/pgp signature, and then (3) run:
#   ./import_openssl.sh openssl-*.tar.gz
#
# IMPORTANT: See README.openssl for additional details.

set -e

die() {
  echo $1
  exit 255
}

if [ $# != 1 ]; then
  die "Usage: ./import_openssl.sh /path/to/openssl-*.tar.gz"
fi

OPENSSL_SOURCE=$1

if [ ! -f openssl.config ]; then
  die "openssl.config not found"
fi

if [ ! -f openssl.version ]; then
  die "openssl.version not found"
fi

if [ ! -d patches ]; then
  die "OpenSSL patch directory patches/ not found"
fi

source openssl.config
source openssl.version

if [ "$CONFIGURE_ARGS" == "" ]; then
  die "Invalid openssl.config; see README.openssl for more information"
fi

NEW_OPENSSL_VERSION=`expr match "$OPENSSL_SOURCE" '.*-\(.*\).tar.gz' || true`
if [ "$NEW_OPENSSL_VERSION" == "" ]; then
  die "Invalid openssl source filename: $OPENSSL_SOURCE"
fi

# Remove old source
if [ "$OPENSSL_VERSION" == "" ]; then
  die "OPENSSL_VERSION not declared in openssl.version"
else
  rm -rf openssl-$OPENSSL_VERSION/
fi

# Process new source
OPENSSL_VERSION=$NEW_OPENSSL_VERSION
rm -rf openssl-$OPENSSL_VERSION/     # remove stale files
tar -zxf $OPENSSL_SOURCE
cd openssl-$OPENSSL_VERSION

./Configure $CONFIGURE_ARGS

# TODO(): Fixup android-config.mk

cp -f LICENSE ../NOTICE
touch ../MODULE_LICENSE_BSD_LIKE

# Prune unnecessary sources
rm -rf $UNNEEDED_SOURCES

# Avoid checking in symlinks
for i in `find include/openssl -type l`; do
  target=`readlink $i`
  rm -f $i
  if [ -f include/openssl/$target ]; then
    cp include/openssl/$target $i
  fi
done

# Apply appropriate patches
for i in $OPENSSL_PATCHES; do
  patch -p1 < ../patches/$i
done

# Copy Makefiles
cp ../patches/apps_Android.mk apps/Android.mk
cp ../patches/crypto_Android.mk crypto/Android.mk
cp ../patches/ssl_Android.mk ssl/Android.mk

cd ..
cp -af openssl-$OPENSSL_VERSION/include .
rm -rf apps/
mv openssl-$OPENSSL_VERSION/apps .
rm -rf ssl/
mv openssl-$OPENSSL_VERSION/ssl .
rm -rf crypto/
mv openssl-$OPENSSL_VERSION/crypto .
rm -f e_os.h e_os2.h
mv openssl-$OPENSSL_VERSION/e_os.h openssl-$OPENSSL_VERSION/e_os2.h .
rm -rf openssl-$OPENSSL_VERSION/
