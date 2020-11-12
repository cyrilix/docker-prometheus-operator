FROM --platform=$BUILDPLATFORM golang:1.15-alpine AS builder-src

ARG version="v0.43.2"
WORKDIR /opt

RUN apk add -U git
RUN git clone https://github.com/coreos/prometheus-operator.git
WORKDIR /opt/prometheus-operator
RUN git checkout ${version}



FROM builder-src AS builder-operator
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    GOARCH=${GOARCH} GOARM=${GOARM} go mod vendor && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} go build -mod=vendor -ldflags="-s -X github.com/coreos/prometheus-operator/pkg/version.Version=${version}" -o operator cmd/operator/main.go



FROM builder-src AS builder-config-reloader
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    GOARCH=${GOARCH} GOARM=${GOARM} go mod vendor && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} go build -mod=vendor -ldflags="-s -X github.com/coreos/prometheus-operator/pkg/version.Version=${version}" -o prometheus-config-reloader cmd/prometheus-config-reloader/main.go





FROM gcr.io/distroless/static AS operator

COPY --from=builder-operator /opt/prometheus-operator/operator /bin/operator
COPY --from=builder-config-reloader /opt/prometheus-operator/prometheus-config-reloader /bin/prometheus-config-reloader


USER 1234

ENTRYPOINT ["/bin/operator"]




FROM gcr.io/distroless/static AS config-reloader

COPY --from=builder-config-reloader /opt/prometheus-operator/prometheus-config-reloader /bin/prometheus-config-reloader

USER 1234

ENTRYPOINT ["/bin/prometheus-config-reloader"]
