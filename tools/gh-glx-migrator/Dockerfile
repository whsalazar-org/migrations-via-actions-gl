FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git make build-base

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o gh-glx-migrator

# Final stage
FROM alpine:3.19

RUN apk add --no-cache github-cli bash
WORKDIR /app

COPY --from=builder /app/gh-glx-migrator /usr/local/bin/
COPY --from=builder /app/scripts/install.sh .

RUN mkdir -p /root/.config/gh/

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["gh", "glx", "--help"]