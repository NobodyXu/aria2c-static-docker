#!/bin/bash -ex

die() {
    cat $1
    exit 1
}

# Generate configure script and other files necessary to build the program
autoreconf -i

./configure ARIA2_STATIC=yes \
            --without-libxml2 \
            --with-ca-bundle='/usr/local/etc/ssl/certs/ca-certificates.crt' || \
            die config.log
make -j $(nproc)
make check
su-exec root:root make install-strip
