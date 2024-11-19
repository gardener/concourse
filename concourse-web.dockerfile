# Global build images
ARG golang_concourse_builder_image=golang:alpine

#
# Build the UI artefacts
FROM debian:bookworm-slim AS yarn-builder
ARG concourse_version=7.12.0

RUN apt-get update && \
 DEBIAN_FRONTEND=noninteractive \
 apt-get install -y --no-install-recommends \
  tzdata \
  git \
  libatomic1 \
  xz-utils \
  chromium-bsu \
  chromium \
  elm-compiler \
  nodejs \
  npm && \
 npm install --global yarn && \
 git clone --branch v${concourse_version} https://github.com/concourse/concourse /yarn/concourse \
&& GIT_DIR=/yarn/concourse/.git \
  git fetch origin c6ae4b6d858ebd0bc74f0ce94231f491d5ccdb18 \
&& GIT_DIR=/yarn/concourse/.git/ GIT_WORK_TREE=/yarn/concourse \
  git checkout c6ae4b6d858ebd0bc74f0ce94231f491d5ccdb18

# Build concourse web
WORKDIR /yarn/concourse

RUN yarn && yarn build


#
# Build the go artefacts
FROM ${golang_concourse_builder_image} AS go-builder

ENV GO111MODULE=on

ARG concourse_version=7.12.0
ARG guardian_commit_id=c4541e8d2645c2cd2b592a1ff053bc2e24902435

RUN apk add gcc git g++

RUN git clone https://github.com/cloudfoundry/guardian.git /go/guardian
WORKDIR /go/guardian
RUN git checkout ${guardian_commit_id}
RUN go build -ldflags "-extldflags '-static'" -mod=vendor -o gdn ./cmd/gdn
WORKDIR /go/guardian/cmd/init
RUN gcc -static -o init init.c ignore_sigchild.c

RUN git clone --branch v${concourse_version} https://github.com/concourse/concourse /go/concourse
WORKDIR /go/concourse
# CGO_FLAGS: https://github.com/mattn/go-sqlite3/issues/1164#issuecomment-1635253695
RUN CGO_CFLAGS="-D_LARGEFILE64_SOURCE" \
  go build -v -ldflags "-extldflags '-static' \
  -X github.com/concourse/concourse.Version=${concourse_version}" ./cmd/concourse

#
# Generate the final image
FROM debian:bookworm-slim

ARG concourse_version=7.12.0
# see https://github.com/robinhuiser/concourse-arm64/tree/main/build-specs
ARG concourse_docker_entrypoint_commit_id=ced6f3117d93121323098d094cf7ccc1776df521

COPY --from=yarn-builder /yarn/concourse/web/public/ /public

COPY --from=go-builder /go/concourse/concourse /usr/local/concourse/bin/
COPY --from=go-builder /go/guardian/gdn /usr/local/concourse/bin/
COPY --from=go-builder /go/guardian/cmd/init/init /usr/local/concourse/bin/


# Auto-wire work dir for 'worker' and 'quickstart'
ENV CONCOURSE_WEB_PUBLIC_DIR=/public

# Volume for non-aufs/etc. mount for baggageclaim's driver
# VOLUME /worker-state

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    dumb-init \
    dos2unix \
&& curl http://aia.pki.co.sap.com/aia/SAP%20Global%20Root%20CA.crt -o \
  /usr/local/share/ca-certificates/SAP_Global_Root_CA.crt \
&& curl http://aia.pki.co.sap.com/aia/SAPNetCA_G2.crt -o \
    /usr/local/share/ca-certificates/SAPNetCA_G2.crt \
&& curl http://aia.pki.co.sap.com/aia/SAP%20Global%20Sub%20CA%2004.crt -o \
    /usr/local/share/ca-certificates/SAP_Global_Sub_CA_04.crt \
&& curl http://aia.pki.co.sap.com/aia/SAP%20Global%20Sub%20CA%2005.crt -o \
    /usr/local/share/ca-certificates/SAP_Global_Sub_CA_05.crt \
&& dos2unix /etc/ssl/certs/ca-certificates.crt \
&& update-ca-certificates \
&& mkdir -p /usr/local/concourse/fly-assets \
&&  curl -sL \
    https://github.com/concourse/concourse/releases/download/v${concourse_version}/fly-${concourse_version}-darwin-amd64.tgz \
    -o /usr/local/concourse/fly-assets/fly-darwin-amd64.tgz && \
  curl -sL  \
    https://github.com/concourse/concourse/releases/download/v${concourse_version}/fly-${concourse_version}-linux-amd64.tgz \
   -o /usr/local/concourse/fly-assets/fly-linux-amd64.tgz && \
  curl \
    -sL https://github.com/concourse/concourse/releases/download/v${concourse_version}/fly-${concourse_version}-windows-amd64.zip \
   -o /usr/local/concourse/fly-assets/fly-windows-amd64.zip \
&& apt-get remove -y \
  curl \
  dos2unix \
&& apt autoremove -y \
&& apt clean


STOPSIGNAL SIGUSR2

ADD https://raw.githubusercontent.com/concourse/concourse-docker/${concourse_docker_entrypoint_commit_id}/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["dumb-init", "/usr/local/bin/entrypoint.sh"]
