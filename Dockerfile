FROM --platform=$BUILDPLATFORM golang:1.13-alpine AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG version="v0.39.0"


WORKDIR /opt

RUN apk add -U git
RUN git clone https://github.com/coreos/prometheus-operator.git
WORKDIR /opt/prometheus-operator
RUN git checkout ${version}

RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} go build -mod=vendor -ldflags="-s -X github.com/coreos/prometheus-operator/pkg/version.Version=${version}" -o operator cmd/operator/main.go




FROM gcr.io/distroless/static

COPY --from=builder /opt/prometheus-operator/operator /bin/operator

USER 1234

ENTRYPOINT ["/bin/operator"]
