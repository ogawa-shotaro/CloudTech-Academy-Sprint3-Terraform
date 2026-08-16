#!/bin/bash
set -e

# Update system
dnf update -y

# Install Go and Git
dnf install -y golang git stress-ng

# Set Go environment variables
export HOME=/root
export GOPATH=/root/go
export GOMODCACHE=/root/go/pkg/mod
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Create app directory
mkdir -p /opt/api
cd /opt/api

# Get instance metadata (for hostname endpoint)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)

# Create the Omikuji API application
cat > main.go << 'GOEOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "math/rand"
    "net/http"
    "os"
    "os/exec"
    "time"
)

type OmikujiResult struct {
    Result  string `json:"result"`
    Message string `json:"message"`
}

type HostnameResult struct {
    Hostname string `json:"hostname"`
}

type HealthResult struct {
    Status string `json:"status"`
}

type StressResult struct {
    Message string `json:"message"`
}

var omikujiList = []OmikujiResult{
    {Result: "大吉", Message: "すべてがうまくいく最高の運勢です！"},
    {Result: "中吉", Message: "良いことが起こりそうな予感です。"},
    {Result: "小吉", Message: "小さな幸せが訪れるでしょう。"},
    {Result: "吉", Message: "穏やかな一日になりそうです。"},
    {Result: "末吉", Message: "努力が実を結ぶ兆しがあります。"},
    {Result: "凶", Message: "慎重に行動することをお勧めします。"},
    {Result: "大凶", Message: "今日は控えめに過ごしましょう。"},
}

func omikujiHandler(w http.ResponseWriter, r *http.Request) {
    rand.Seed(time.Now().UnixNano())
    result := omikujiList[rand.Intn(len(omikujiList))]

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}

func hostnameHandler(w http.ResponseWriter, r *http.Request) {
    hostname := os.Getenv("INSTANCE_ID")
    if hostname == "" {
        hostname, _ = os.Hostname()
    }

    result := HostnameResult{Hostname: hostname}
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    result := HealthResult{Status: "healthy"}
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}

func stressHandler(w http.ResponseWriter, r *http.Request) {
    go func() {
        cmd := exec.Command("stress-ng", "--cpu", "1", "--timeout", "60s")
        cmd.Run()
    }()

    result := StressResult{Message: "CPU stress test started for 60 seconds"}
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(result)
}

func main() {
    http.HandleFunc("/omikuji", omikujiHandler)
    http.HandleFunc("/hostname", hostnameHandler)
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/stress", stressHandler)

    fmt.Println("Starting Omikuji API server on port 80...")
    log.Fatal(http.ListenAndServe(":80", nil))
}
GOEOF

# Initialize Go module
go mod init omikuji-api
go mod tidy

# Build the application
go build -o omikuji-api main.go

# Create systemd service
cat > /etc/systemd/system/omikuji-api.service << SERVICEEOF
[Unit]
Description=Omikuji API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/api
Environment="INSTANCE_ID=$INSTANCE_ID"
ExecStart=/opt/api/omikuji-api
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable and start service
systemctl daemon-reload
systemctl enable omikuji-api
systemctl start omikuji-api
