FROM nobodyxu/apt-fast:latest-debian-buster AS base

ADD install_llvm.sh /tmp/

# The first line of packages is for cloning
# The second and third line are for linking with runtime library
# The fourth line and the last one are build tools
RUN apt-fast update && \
    apt-fast install -y --no-install-recommends \
                     git ca-certificates \
                     libgnutls28-dev nettle-dev libgmp-dev libssh2-1-dev libc-ares-dev libxml2-dev \
                     zlib1g-dev libsqlite3-dev liblzma-dev libunistring-dev libp11-kit-dev \
                     pkg-config libcppunit-dev autoconf automake \
                     autotools-dev autopoint libtool libxml2-dev make

ARG toolchain=llvm
# Install llvm only when asked
RUN if [ $toolchain = "llvm" ]; then /tmp/install_llvm.sh; else apt-fast update && apt-fast install -y gcc g++; fi

RUN mkdir -p /usr/local/etc/ssl/certs/ && cp /etc/ssl/certs/ca-certificates.crt /usr/local/etc/ssl/certs/

FROM base AS Build

RUN useradd -m user && mkdir -p /usr/local/src && chmod -R 777 /usr/local/src
ADD rm_aria2.sh /usr/local/bin/

# Install su-exec to replace sudo
ADD https://github.com/NobodyXu/su-exec/releases/download/v0.3/su-exec /usr/local/bin/su-exec
RUN chmod a+xs /usr/local/bin/su-exec

USER user
ARG branch=release-1.35.0
RUN git clone --depth 1 -b $branch https://github.com/aria2/aria2.git /usr/local/src/aria2
WORKDIR /usr/local/src/aria2

# Add -v as it fix the build somehow
ENV CC="/usr/bin/cc" CXX="/usr/bin/c++" CFLAGS="-flto -v" CXXFLAGS="-flto -v"

ADD compile.sh /tmp/
RUN /tmp/compile.sh

FROM Build AS Clean

# Remove the source code
WORKDIR /
RUN rm -rf /usr/local/src/aria2

# Copy necessary
# Remove doc and manpage
RUN su-exec root:root rm -r /usr/local/share/doc/* /usr/local/share/man/*
# Remove apt-fast
RUN su-exec root:root /usr/local/sbin/rm_apt-fast.sh
# Remove su-exec
RUN su-exec root:root rm /usr/local/bin/su-exec

FROM debian:buster AS Final
COPY --from=Clean /usr/local/ /usr/local/
