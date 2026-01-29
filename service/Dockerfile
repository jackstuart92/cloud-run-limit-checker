# Stage 1: build
FROM golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod ./
# no go.sum needed (no external deps)
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o service .

# Stage 2: runtime
FROM gcr.io/distroless/static-debian12
COPY --from=build /app/service /service
ENTRYPOINT ["/service"]
