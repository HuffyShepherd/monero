# Multistage docker build, requires docker 17.05

# builder stage
FROM ubuntu:focal as builder

ARG TARGET=x86_64-linux-gnu

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

WORKDIR /src
COPY . .

ARG NPROC
ENV USE_SINGLE_BUILDDIR=1
ENV PATH=/src/contrib/depends/${TARGET}/native/bin:$PATH

RUN [ "$TARGET" = "aarch64-linux-android" ] && apt-get install -y python || true

RUN set -ex && \
    git submodule init && git submodule update && \
    rm -rf build && \
    if [ -z "$NPROC" ] ; \
    then make -j$(nproc) depends target=${TARGET} ; \
    else make -j$NPROC depends target=${TARGET} ; \
    fi

# runtime stage
FROM ubuntu:focal

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt

ARG TARGET=x86_64-linux-gnu
COPY --from=builder /src/build/${TARGET}/release/bin /usr/local/bin/

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
