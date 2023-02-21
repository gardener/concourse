FROM golang:1.20-alpine as builder

ARG time_resource_version=1.6.3

RUN apk add git
RUN git clone --depth 1 --branch v${time_resource_version} https://github.com/concourse/time-resource.git /src/time-resource
WORKDIR /src/time-resource
ENV CGO_ENABLED 0
RUN go get -d ./...
RUN go build -o /assets/in ./in
RUN go build -o /assets/out ./out
RUN go build -o /assets/check ./check

FROM alpine:edge AS resource
RUN apk add --no-cache bash tzdata
COPY --from=builder assets/ /opt/resource/
RUN chmod +x /opt/resource/*

FROM resource
