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
RUN chmod +x /assets/*

FROM gcr.io/distroless/static-debian11
COPY --from=builder assets/ /opt/resource/
