FROM golang:alpine AS builder

ARG registry_image_resource_version=1.10.0

RUN apk add git
RUN git clone --depth 1 --branch v${registry_image_resource_version} https://github.com/concourse/registry-image-resource.git /src/registry-image-resource
WORKDIR /src/registry-image-resource
ENV CGO_ENABLED 0
RUN go get -d ./...
RUN go build -o /assets/in ./cmd/in
RUN go build -o /assets/out ./cmd/out
RUN go build -o /assets/check ./cmd/check
RUN chmod +x /assets/*
# Ensure /etc/hosts is honored
# https://github.com/golang/go/issues/22846
# https://github.com/gliderlabs/docker-alpine/issues/367
RUN echo "hosts: files dns" > /etc/nsswitch.conf

FROM gcr.io/distroless/static-debian12 AS resource
COPY --from=builder assets/ /opt/resource/
COPY --from=builder /etc/nsswitch.conf /etc/nsswitch.conf

FROM resource
