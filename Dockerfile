# #  _                     __       _            __
# # | |                   / /      | |          / _|
# # | |__   ___ ___      / /    ___| |__  _ __ | |_
# # | '_ \ / __/ __|    / /    / _ \ '_ \| '_ \|  _|
# # | |_) | (_| (__    / /    |  __/ |_) | |_) | |
# # |_.__/ \___\___|  /_/      \___|_.__/| .__/|_|
# #                                      | |
# #                                      |_|

# # copied from here https://github.com/iovisor/bcc/blob/master/INSTALL.md#alpine---source
# FROM alpine:3.12 as bcc-builder

# RUN apk add tar git build-base iperf linux-headers llvm10-dev llvm10-static \
#   clang-dev clang-static cmake python3 flex-dev bison luajit-dev elfutils-dev \
#   zlib-dev

# WORKDIR /opt/bcc

# RUN git clone https://github.com/iovisor/bcc.git
# RUN mkdir bcc/build && cd bcc/build && cmake -DENABLE_EXAMPLES=NO -DPYTHON_CMD=python3 .. && make && make install

#                 _
#                | |
#  _ __ _   _ ___| |_
# | '__| | | / __| __|
# | |  | |_| \__ \ |_
# |_|   \__,_|___/\__|

FROM alpine:3.12 as rust-builder

RUN apk update &&\
    apk add git gcc g++ make build-base openssl-dev musl musl-dev \
    rust cargo curl

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN /root/.cargo/bin/rustup target add $(uname -m)-unknown-linux-musl

RUN wget https://github.com/libunwind/libunwind/releases/download/v1.3.1/libunwind-1.3.1.tar.gz
RUN tar -zxvf libunwind-1.3.1.tar.gz
RUN cd libunwind-1.3.1/ && ./configure --disable-minidebuginfo --enable-ptrace --disable-tests --disable-documentation && make && make install

COPY third_party/rustdeps /opt/rustdeps

WORKDIR /opt/rustdeps

ENV RUSTFLAGS="-C target-feature=+crt-static"
RUN /root/.cargo/bin/cargo build --release --target $(uname -m)-unknown-linux-musl
RUN mv /opt/rustdeps/target/$(uname -m)-unknown-linux-musl/release/librustdeps.a /opt/rustdeps/librustdeps.a


#                     _
#                    | |
#   __ _ ___ ___  ___| |_ ___
#  / _` / __/ __|/ _ \ __/ __|
# | (_| \__ \__ \  __/ |_\__ \
#  \__,_|___/___/\___|\__|___/

FROM node:14.15.1-alpine3.12 as js-builder

RUN apk add --no-cache make

WORKDIR /opt/pyroscope

COPY scripts ./scripts
COPY webapp ./webapp
COPY package.json yarn.lock babel.config.js .eslintrc .eslintignore Makefile ./

ARG EXTRA_METADATA=""
RUN EXTRA_METADATA=$EXTRA_METADATA make assets-release


#              _
#             | |
#   __ _  ___ | | __ _ _ __   __ _
#  / _` |/ _ \| |/ _` | '_ \ / _` |
# | (_| | (_) | | (_| | | | | (_| |
#  \__, |\___/|_|\__,_|_| |_|\__, |
#   __/ |                     __/ |
#  |___/                     |___/

FROM golang:1.15.1-alpine3.12 as go-builder

RUN apk add --no-cache make git zstd gcc g++ libc-dev musl-dev

#  _                     __       _            __
# # | |                   / /      | |          / _|
# # | |__   ___ ___      / /    ___| |__  _ __ | |_
# # | '_ \ / __/ __|    / /    / _ \ '_ \| '_ \|  _|
# # | |_) | (_| (__    / /    |  __/ |_) | |_) | |
# # |_.__/ \___\___|  /_/      \___|_.__/| .__/|_|
# #                                      | |
# #                                      |_|

# # copied from here https://github.com/iovisor/bcc/blob/master/INSTALL.md#alpine---source
# FROM alpine:3.12 as bcc-builder

RUN apk add tar git build-base iperf linux-headers llvm10-dev llvm10-static \
  clang-dev clang-static cmake python3 flex-dev bison luajit-dev elfutils-dev \
  zlib-dev

RUN apk add libelf-static zlib-static ncurses-static

WORKDIR /opt/bcc

RUN git clone https://github.com/iovisor/bcc.git
RUN mkdir bcc/build && cd bcc/build && cmake -DENABLE_EXAMPLES=NO -DPYTHON_CMD=python3 .. && make && make install

WORKDIR /opt/pyroscope

RUN mkdir -p /opt/pyroscope/third_party/rustdeps/target/release
COPY --from=rust-builder /opt/rustdeps/librustdeps.a /opt/pyroscope/third_party/rustdeps/target/release/librustdeps.a
COPY third_party/rustdeps/rbspy.h /opt/pyroscope/third_party/rustdeps/rbspy.h
COPY third_party/rustdeps/pyspy.h /opt/pyroscope/third_party/rustdeps/pyspy.h

COPY --from=js-builder /opt/pyroscope/webapp/public ./webapp/public
COPY pkg ./pkg
COPY cmd ./cmd
COPY tools ./tools
COPY scripts ./scripts
COPY go.mod go.sum pyroscope.go ./
COPY Makefile ./

# go build -ldflags "-linkmode external -extldflags \"-static -lbcc -lbcc_bpf -lbcc-loader-static -lbcc -lbcc_bpf -lbcc -loader-static -lelf -L/usr/lib/llvm10/lib $(cat clang.txt) $(cat llvm.txt) $(cat llvm.txt) $(cat llvm.txt) -lz -lrt -ldl -lncursesw -lstdc++ -lstdc++fs\"" ./examples/bcc/perf
# go build -ldflags "-linkmode external -extldflags \"-static -lbcc -lbcc_bpf -lbcc-loader-static -lelf -lz -L/usr/lib/llvm10/lib $(cat clang.txt) $(cat llvm.txt) -lrt -ldl -lncursesw -lstdc++ -lstdc++fs\"" ./examples/bcc/perf
RUN EMBEDDED_ASSETS_DEPS="" EXTRA_LDFLAGS="-linkmode external -extldflags \"-static -lelf -lz -lLLVM\"" make build-release


#   __ _             _   _
#  / _(_)           | | (_)
# | |_ _ _ __   __ _| |  _ _ __ ___   __ _  __ _  ___
# |  _| | '_ \ / _` | | | | '_ ` _ \ / _` |/ _` |/ _ \
# | | | | | | | (_| | | | | | | | | | (_| | (_| |  __/
# |_| |_|_| |_|\__,_|_| |_|_| |_| |_|\__,_|\__, |\___|
#                                           __/ |
#                                          |___/

FROM alpine:3.12

LABEL maintainer="Pyroscope team <hello@pyroscope.io>"

WORKDIR /var/lib/pyroscope

RUN apk add --no-cache ca-certificates bash tzdata openssl musl-utils

RUN addgroup -S pyroscope && adduser -S pyroscope -G pyroscope

RUN mkdir -p \
        "/var/lib/pyroscope" \
        "/var/log/pyroscope" \
        "/etc/pyroscope" \
        && \
    chown -R "pyroscope:pyroscope" \
        "/var/lib/pyroscope" \
        "/var/log/pyroscope" \
        "/etc/pyroscope" \
        && \
    chmod -R 777 \
        "/var/lib/pyroscope" \
        "/var/log/pyroscope" \
        "/etc/pyroscope"

COPY scripts/packages/server.yml "/etc/pyroscope/server.yml"
COPY --from=go-builder /opt/pyroscope/bin/pyroscope /usr/bin/pyroscope
RUN chmod 777 /usr/bin/pyroscope

USER pyroscope
EXPOSE 4040/tcp
ENTRYPOINT [ "/usr/bin/pyroscope" ]
