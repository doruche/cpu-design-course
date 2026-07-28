FROM ubuntu:24.04

ARG JUST_VERSION=1.42.4
# docs/baseline.md pins Verilator 5.051 devel, revision v5.050-59-gdde8de0a0.
# Ubuntu 24.04 ships 5.020, which does not know lint rules the waiver files use.
# The full SHA is required: a shallow fetch cannot resolve an abbreviated ref.
ARG VERILATOR_REV=dde8de0a0dd5360e29df366d05dc595636e97bb3

ENV DEBIAN_FRONTEND=noninteractive

# archive.ubuntu.com is effectively unreachable from this network; use a mirror.
# Plain HTTP is required: the base image ships no CA certificates, so an HTTPS
# mirror cannot be verified until ca-certificates is installed below.
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.aliyun.com/ubuntu|g; s|http://security.ubuntu.com/ubuntu|http://mirrors.aliyun.com/ubuntu|g' \
        /etc/apt/sources.list.d/ubuntu.sources

# Tools required by scripts/doctor.sh. gtkwave is in doctor.sh's optional list and
# pulls the whole GTK/X11 stack, so it is deliberately omitted; waveform inspection
# happens on the host.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        gcc-riscv64-unknown-elf \
        git \
        iverilog \
        libxml2-utils \
        make \
        picolibc-riscv64-unknown-elf \
        python3 \
        ripgrep \
        rsync \
        sudo \
        unzip \
        util-linux \
        xz-utils \
        autoconf \
        bison \
        flex \
        help2man \
        libfl-dev \
        perl \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Verilator is built from the pinned revision rather than installed from apt so
# that lint waivers in config/*.vlt resolve to known rule names.
# A full clone of the upstream history reliably dies on this network, so fetch
# only the pinned commit.
RUN mkdir /tmp/verilator && cd /tmp/verilator \
    && git init -q \
    && git fetch --depth 1 https://github.com/verilator/verilator.git "${VERILATOR_REV}" \
    && git checkout -q FETCH_HEAD \
    && autoconf && ./configure && make -j"$(nproc)" && make install \
    && rm -rf /tmp/verilator

# just is not packaged for Ubuntu 24.04 and doctor.sh requires >= 1.40.0.
RUN curl -fsSL \
        "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin just

# The C_TEST programs invoke riscv32-unknown-elf-* with -march=rv32im -mabi=ilp32.
# Ubuntu ships that toolchain under the riscv64- prefix; its multilib set includes
# rv32im/ilp32, so alias it to the prefix the course scripts expect.
RUN for tool in /usr/bin/riscv64-unknown-elf-*; do \
        ln -s "$tool" "/usr/local/bin/riscv32-unknown-elf-${tool##*/riscv64-unknown-elf-}"; \
    done

# Match the host user so bind-mounted files keep their ownership.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
