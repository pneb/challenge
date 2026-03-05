FROM debian:bullseye

#Docker Arguments
#old code start
#ARG OPENSSL_BRANCH
#old code end
ARG OPENSSL_REPO
ARG LIBOQS_COMMIT
#new code start
#Add build args for oqs-provider source selection
ARG LIBOQS_REPO
ARG OQSPROVIDER_REPO
ARG OPENSSL_COMMIT
ARG OQSPROVIDER_COMMIT
#new code end

#liboqs build type variant; maximum portability of image:
ENV LIBOQS_BUILD_DEFINES "-DOQS_DIST_BUILD=ON"
#old code start
#ENV OPENSSL_BUILD_DEFINES "-DOQS_DEFAULT_GROUPS=p384_kyber768:X25519:kyber768"
#old code end
ENV OPENSSL_PATH /opt/openssl
ENV OPENSSL_SRC_PATH /opt/openssl-src
#new code start
# Define liboqs and oqs-provider paths for build/install
ENV LIBOQS_PATH /opt/liboqs
ENV OQSPROVIDER_SRC_PATH /opt/oqs-provider-src
#new code end
ENV MAKE_DEFINES "-j 18"
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y build-essential iproute2 \
            libtool automake autoconf cmake ninja-build dnsutils tcpdump \
            make \
            openssl libssl-dev \
            git wget libpcre3 libpcre3-dev

#old code start
#RUN mkdir -p /opt $OPENSSL_PATH $OPENSSL_SRC_PATH /out
#old code end

WORKDIR /opt

#old code start
#RUN git clone --branch main https://github.com/open-quantum-safe/liboqs && \
#   git clone --depth 1 --branch ${OPENSSL_BRANCH} ${OPENSSL_REPO} ${OPENSSL_SRC_PATH}
#old code end

#new code start
#Clone liboqs, OpenSSL, and oqs-provider sources
RUN git clone ${LIBOQS_REPO} ${LIBOQS_PATH} && \
    git clone ${OPENSSL_REPO} ${OPENSSL_SRC_PATH} && \
    git clone ${OQSPROVIDER_REPO} ${OQSPROVIDER_SRC_PATH}

#switch to specified commits
WORKDIR ${LIBOQS_PATH}
RUN git checkout ${LIBOQS_COMMIT}

WORKDIR ${OPENSSL_SRC_PATH}
RUN git checkout ${OPENSSL_COMMIT}

WORKDIR ${OQSPROVIDER_SRC_PATH}
RUN git checkout ${OQSPROVIDER_COMMIT} 
#new code end

#old code start
#WORKDIR /opt/liboqs
#old code end

#new code start
#Switch to the liboqs source directory before building
WORKDIR ${LIBOQS_PATH}
#new code end

#old code start
# Build LibOQS
#RUN git checkout $LIBOQS_COMMIT && mkdir -p build-static
#WORKDIR /opt/liboqs/build-static
#RUN cmake -G"Ninja" ${LIBOQS_BUILD_DEFINES} -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=${OPENSSL_SRC_PATH}/oqs ..
#RUN ninja
#RUN ninja install

#WORKDIR /opt/liboqs

#RUN mkdir -p build && cd build  && \
#    cmake -G"Ninja" .. ${LIBOQS_BUILD_DEFINES} -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/opt/ossl-src/oqs && \
#    ninja install
#old code end

#new code start
#Build and install shared liboqs into LIBOQS_PATH
RUN mkdir -p build
WORKDIR ${LIBOQS_PATH}/build
RUN cmake -G"Ninja" ${LIBOQS_BUILD_DEFINES} -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=${LIBOQS_PATH} .. && \
	ninja && \
	ninja install
#new code end

# build openssl
WORKDIR $OPENSSL_SRC_PATH
#old code start
#ENV LDFLAGS "-Wl,-rpath -Wl,${OPENSSL_PATH}/lib"
#old code end

#old code start
#RUN ./config shared ${OPENSSL_BUILD_DEFINES} --prefix=${OPENSSL_PATH} && \
#    make generate_crypto_objects && \
#    make ${MAKE_DEFINES} && \
#    make install
#old code start

#new code start
#Build OpenSSL 3.6 and then build/install oqs-provider against liboqs
RUN ./Configure linux-x86_64 shared --prefix=${OPENSSL_PATH} --openssldir=${OPENSSL_PATH}/ssl --libdir=lib && \
    make ${MAKE_DEFINES} && \
    make install

#build oqs-provider
WORKDIR ${OQSPROVIDER_SRC_PATH}
RUN cmake -S . -B build -G"Ninja" -DOPENSSL_ROOT_DIR=${OPENSSL_PATH} -Dliboqs_DIR=${LIBOQS_PATH}/lib/cmake/liboqs \
    -DCMAKE_INSTALL_PREFIX=${OPENSSL_PATH} -DCMAKE_INSTALL_LIBDIR=lib && \
    ninja -C build && \
    ninja -C build install
#new code end

ARG CPU_PROFILING
RUN if [ "$CPU_PROFILING" = "True" ]; then \
    apt-get install -y linux-perf; fi

#new code start  
#Set runtime env so OpenSSL can load oqs-provider and liboqs
ENV LD_LIBRARY_PATH "${LIBOQS_PATH}/lib:${LIBOQS_PATH}/lib64:${OPENSSL_PATH}/lib:${OPENSSL_PATH}/lib64"
ENV OPENSSL_MODULES "${OPENSSL_PATH}/lib/ossl-modules"
ENV OPENSSL_PROVIDER_ARGS "-provider oqsprovider -provider default"
#new code end


ENV OPENSSL "${OPENSSL_PATH}/bin/openssl"
ENV OPENSSL_CNF "${OPENSSL_PATH}/ssl/openssl.cnf"
#new code start
#Export the default OpenSSL config path for runtime
ENV OPENSSL_CONF "${OPENSSL_PATH}/ssl/openssl.cnf"
#new code end

WORKDIR /opt
COPY measurement-openssl-client.sh /opt/
COPY measurement-openssl-server.sh /opt/
