# 🖥️ Homelab Server - HP Pavilion i3 Gen4

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-12-red.svg)](https://www.debian.org/)
[![Caddy](https://img.shields.io/badge/Caddy-2.6-blue.svg)](https://caddyserver.com/)
[![Docker](https://img.shields.io/badge/Docker-24.0-blue.svg)](https://www.docker.com/)

> **Full-stack homelab server untuk laptop jadul** - Caddy + Cloudflare Tunnel + WordPress + ERPNext + AI Agent (Ollama + FastAPI)

---

## 📋 Spesifikasi Hardware

| Komponen | Spesifikasi |
|----------|-------------|
| **Laptop** | HP Pavilion |
| **CPU** | Intel Core i3 Gen 4 (2 Core, 4 Thread) |
| **RAM** | 4GB DDR3 |
| **Storage** | 320GB HDD (5400 RPM) |
| **OS** | Debian 12 (minimal, CLI-only) |

---

## 🎯 Aplikasi yang Dideploy

| Aplikasi | Teknologi | Port | Status |
|----------|-----------|------|--------|
| **Web Server** | Caddy (reverse proxy + auto HTTPS) | 80/443 | ✅ Native |
| **WordPress** | WordPress + SQLite (no MySQL) | 8080 | ✅ Native |
| **Static Site** | HTML/CSS/JS | 8081 | ✅ Native |
| **ERPNext** | Frappe Framework + PostgreSQL | 8000 | ✅ Native (optional) |
| **AI Agent** | FastAPI + Ollama (TinyLlama) | 5000 | 🐳 Docker |

---

## 🚀 Quick Start (3 Langkah)

### 1️⃣ Clone Repository
```bash
git clone https://github.com/efansb/homelab-server.git
cd homelab-server