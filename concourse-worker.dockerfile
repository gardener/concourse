# Global build images
ARG golang_concourse_builder_image

#
# Build the go artefacts
FROM ${golang_concourse_builder_image} AS go-builder

ENV GO111MODULE=on

ARG concourse_version
ARG guardian_commit_id
ARG cni_plugins_version

RUN apk add gcc git g++

RUN git clone https://github.com/cloudfoundry/guardian.git /go/guardian
WORKDIR /go/guardian
RUN git checkout ${guardian_commit_id}
RUN go build -ldflags "-extldflags '-static'" -mod=vendor -o gdn ./cmd/gdn
WORKDIR /go/guardian/cmd/init
RUN gcc -static -o init init.c ignore_sigchild.c

RUN git clone --branch v${concourse_version} https://github.com/concourse/concourse /go/concourse
WORKDIR /go/concourse
RUN go build -v -ldflags "-extldflags '-static' -X github.com/concourse/concourse.Version=${concourse_version}" ./cmd/concourse

RUN git clone --branch v${cni_plugins_version} https://github.com/containernetworking/plugins.git /go/plugins
WORKDIR /go/plugins
RUN apk add bash
ENV CGO_ENABLED=0
RUN ./build_linux.sh


#
# Generate the final image
FROM debian:bookworm-slim

ARG concourse_version
ARG concourse_docker_entrypoint_commit_id

COPY --from=go-builder /go/concourse/concourse /usr/local/concourse/bin/
COPY --from=go-builder /go/guardian/gdn /usr/local/concourse/bin/
COPY --from=go-builder /go/guardian/cmd/init/init /usr/local/concourse/bin/
COPY --from=go-builder /go/plugins/bin/* /usr/local/concourse/bin/


# Add resource-types
COPY out.d/resource-types /usr/local/concourse/resource-types

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
    iptables \
    dumb-init \
    iproute2 \
    file \
    curl

STOPSIGNAL SIGUSR2

ADD https://raw.githubusercontent.com/concourse/concourse-docker/${concourse_docker_entrypoint_commit_id}/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["dumb-init", "/usr/local/bin/entrypoint.sh"]
