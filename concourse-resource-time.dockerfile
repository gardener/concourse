# syntax=docker/dockerfile:1-labs
FROM golang:1.21-alpine as builder

ARG time_resource_version=v1.7.0

RUN mkdir /src
ADD --keep-git-dir=false \
  https://github.com/concourse/time-resource.git#${time_resource_version} \
  /src/time-resource
WORKDIR /src/time-resource
ENV CGO_ENABLED 0
RUN go get -d ./...
RUN go build -o /assets/in ./in
RUN go build -o /assets/out ./out
RUN go build -o /assets/check ./check
RUN chmod +x /assets/*

FROM gcr.io/distroless/static-debian11
COPY --from=builder assets/ /opt/resource/
