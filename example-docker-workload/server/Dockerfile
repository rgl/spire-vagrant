#syntax=docker/dockerfile:1.4
FROM golang:1.18.2-bullseye AS build
WORKDIR /build
COPY go.* ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s"

FROM debian:bullseye-slim
RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends \
    openssl
rm -rf /var/lib/apt/lists/*
EOF
COPY --from=build /build/server /app/
ENTRYPOINT ["/app/server"]
