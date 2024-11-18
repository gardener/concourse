# Global build images
ARG golang_concourse_builder_image=golang:alpine

#
# Build the go artefacts
FROM ${golang_concourse_builder_image} AS go-builder

ENV GO111MODULE=on

ARG concourse_version=7.12.0
ARG guardian_commit_id=c4541e8d2645c2cd2b592a1ff053bc2e24902435
ARG cni_plugins_version=1.6.0

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
    go build -v -ldflags "-extldflags '-static'\
    -X github.com/concourse/concourse.Version=${concourse_version}" ./cmd/concourse

RUN git clone --branch v${cni_plugins_version} https://github.com/containernetworking/plugins.git /go/plugins
WORKDIR /go/plugins
RUN apk add bash
ENV CGO_ENABLED=0
RUN ./build_linux.sh


#
# Generate the final image
FROM debian:bookworm-slim

# https://github.com/concourse/concourse-docker
ARG concourse_docker_entrypoint_commit_id=ced6f3117d93121323098d094cf7ccc1776df521

COPY --from=go-builder /go/concourse/concourse /usr/local/concourse/bin/
COPY --from=go-builder /go/guardian/gdn /usr/local/concourse/bin/
COPY --from=go-builder /go/guardian/cmd/init/init /usr/local/concourse/bin/
COPY --from=go-builder /go/plugins/bin/* /usr/local/concourse/bin/


# Add resource-types
COPY resource-types /usr/local/concourse/resource-types

# Auto-wire work dir for 'worker' and 'quickstart'
ENV CONCOURSE_WORK_DIR                /worker-state
ENV CONCOURSE_WORKER_WORK_DIR         /worker-state
ENV CONCOURSE_WEB_PUBLIC_DIR          /public

# Volume for non-aufs/etc. mount for baggageclaim's driver
VOLUME /worker-state

RUN apt-get update && apt-get install -y \
    btrfs-progs \
    ca-certificates \
    containerd \
    dos2unix \
    iptables \
    dumb-init \
    iproute2 \
    file \
    curl \
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
&& apt-get remove -y \
    curl \
    dos2unix \
&& apt autoremove -y \
&& apt clean


STOPSIGNAL SIGUSR2

ADD https://raw.githubusercontent.com/concourse/concourse-docker/${concourse_docker_entrypoint_commit_id}/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["dumb-init", "/usr/local/bin/entrypoint.sh"]
