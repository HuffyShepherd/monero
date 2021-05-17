# Multistage docker build, requires docker 17.05

# builder stage
FROM ubuntu:bionic as builder

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install \
        ca-certificates \
        cmake \
        g++ \
        make \
        pkg-config \
        graphviz \
        doxygen \
        git \
        curl \
        libtool-bin \
        autoconf \
        automake \
        bzip2 \
        xsltproc \
        gperf \
        unzip


ARG DTARGET=x86_64-linux-gnu
ARG NPROC
ENV USE_SINGLE_BUILDDIR=1
ENV PATH=/src/contrib/depends/${DTARGET}/native/bin:$PATH

RUN set -eux; \
case "$DTARGET" in \
  "x86_64-w64-mingw32") \
    apt-get install -y python3 g++-mingw-w64-x86-64 wine1.6 bc \
    && update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix \
    && rm /usr/bin/x86_64-w64-mingw32-gcc \
    && ln /usr/bin/x86_64-w64-mingw32-gcc-posix /usr/bin/x86_64-w64-mingw32-gcc \
    ;; \
  "i686-linux-gnu") \
    apt-get install -y g++-multilib bc \
    ;; \
  "i686-w64-mingw32") \
    apt-get install -y python3 g++-mingw-w64-i686 \
    && update-alternatives --set i686-w64-mingw32-g++ /usr/bin/i686-w64-mingw32-g++-posix \
    && rm /usr/bin/i686-w64-mingw32-gcc \
    && ln /usr/bin/i686-w64-mingw32-gcc-posix /usr/bin/i686-w64-mingw32-gcc \
    ;; \
  "arm-linux-gnueabihf") \
    apt-get install -y g++-arm-linux-gnueabihf \
    ;; \
  "aarch64-linux-gnu") \
    apt-get install -y g++-aarch64-linux-gnu \
    ;; \
  "riscv64-linux-gnu") \
    apt-get install -y g++-riscv64-linux-gnu \
    ;; \
  "x86_64-unknown-freebsd") \
    apt-get install -y clang-8 \
    ;; \
  "arm-linux-android") \
    apt-get install -y python \
    ;; \
  "aarch64-linux-android") \
    apt-get install -y python \
    ;; \
esac;

WORKDIR /src
COPY . .

RUN set -ex && \
    git submodule init && git submodule update && \
    rm -rf build && \
    if [ -z "$NPROC" ] ; \
    then make -j$(nproc) depends target=${DTARGET} ; \
    else make -j$NPROC depends target=${DTARGET} ; \
    fi

# runtime stage
FROM ubuntu:bionic

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt

ARG DTARGET=x86_64-linux-gnu
COPY --from=builder /src/build/${DTARGET}/release/bin /usr/local/bin/

# Create monero user
RUN adduser --system --group --disabled-password monero && \
        mkdir -p /wallet /home/monero/.bitmonero && \
        chown -R monero:monero /home/monero/.bitmonero && \
        chown -R monero:monero /wallet

# Contains the blockchain
VOLUME /home/monero/.bitmonero

# Generate your wallet via accessing the container and run:
# cd /wallet
# monero-wallet-cli
VOLUME /wallet

EXPOSE 18080
EXPOSE 18081

# switch to user monero
USER monero

ENTRYPOINT ["monerod"]
CMD ["--p2p-bind-ip=0.0.0.0", "--p2p-bind-port=18080", "--rpc-bind-ip=0.0.0.0", "--rpc-bind-port=18081", "--non-interactive", "--confirm-external-bind"]
