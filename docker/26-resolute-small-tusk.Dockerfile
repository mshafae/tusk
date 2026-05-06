# syntax=docker/dockerfile:1
   
FROM ubuntu:resolute AS intermediate

LABEL org.opencontainers.image.authors="Michael Shafae <mshafae@fullerton.edu>"
LABEL org.opencontainers.image.title="26-resolute-small-tusk"
LABEL org.opencontainers.image.source="https://github.com/mshafae/tusk"
LABEL org.opencontainers.image.description="A development container based on Ubuntu 26 (Resolute) with clang/LLVM for Makefile based C++ projects; includes an unprivileged user 'tuffy' with git configured for command line usage. Localized to C.UTF-8 and set in PDT timezone."

# Set locale
ENV LANG=C.UTF-8
# Set timezone
ENV TZ=PDT

# Install packages, clean up packages, remove /var/lib/apt/lists, set timezone,
# and add Tuffy user
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get -qq update && \
    apt-get install -qqy --no-install-recommends \
        ca-certificates \
        git python3-pexpect \
        # gsfonts graphicsmagick libgraphicsmagick++1-dev \
        make libc6-dev libgmock-dev libgtest-dev \
        clang clang-format clang-tidy && \
    apt-get clean all && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    useradd --comment "Tuffy Titan" --create-home --shell /bin/bash tuffy

ADD --chown=tuffy:tuffy https://raw.githubusercontent.com/mshafae/tusk/refs/heads/main/docker/tuffy-gitconfig /home/tuffy/.gitconfig

ADD --chown=tuffy:tuffy --chmod=755 https://raw.githubusercontent.com/mshafae/tusk/refs/heads/main/docker/codespace-post-start.sh /home/tuffy/.codespace-post-start.sh

FROM intermediate AS test
ARG MS_GITHUB_PAT

ENV MS_GITHUB_PAT=${MS_GITHUB_PAT?ms_github_pat_not_set}
ENV TESTNAME="cpsc-120-env-test"
ENV ENVTEST_TAG="v1.2"

ADD --chown=tuffy:tuffy \
    https://$MS_GITHUB_PAT@github.com/csufcs/${TESTNAME}.git#$ENVTEST_TAG /$TESTNAME
# WORKDIR /$TESTNAME
# RUN ./git-test.sh
WORKDIR /$TESTNAME/part-1
RUN make test
WORKDIR /$TESTNAME/part-2
RUN make test
# This test requires gsfonts graphicsmagick libgraphicsmagick++1-dev packages
# WORKDIR /$TESTNAME/part-3
# RUN make test

FROM intermediate AS final
