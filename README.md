# 🚀 Food Ordering System — ENG23 3074

> ระบบจำลองการสั่งอาหาร (Full-Stack) ที่รองรับการ Build, Test และ Deploy อัตโนมัติผ่าน CI/CD Pipeline พร้อมระบบ Infrastructure as Code (IaC) และ Monitoring เต็มรูปแบบ

---

## 📌 1. ภาพรวมโปรเจค (Project Overview)

ระบบ Food Ordering ประกอบด้วย 2 ส่วนหลัก:
1. **Frontend (หน้าบ้าน):** พัฒนาด้วย `React (Vite)` เสิร์ฟผ่าน `Nginx` เป็นหน้า UI สำหรับให้ผู้ใช้กดสั่งอาหาร
2. **Backend (หลังบ้าน):** พัฒนาด้วย `Go (Gin)` ทำหน้าที่จัดการคำสั่งซื้อ (REST API) และพ่นข้อมูล Metrics 

**เป้าหมายหลัก:** วางระบบ DevOps Pipeline อัตโนมัติ เมื่อมีการ Push โค้ด ระบบจะทำการ Build Container, จัดเตรียม Infrastructure และ Deploy ขึ้น Kubernetes อัตโนมัติ พร้อมแสดงผลสถานะระบบผ่าน Grafana Dashboard

---

## 🏗️ 2. System Architecture

```text
Developer
    │
    ▼  git push
 GitHub ──── webhook ────▶ Jenkins CI/CD
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
                 Build        Test      Docker Build (2 Images)
                                            │
                                            ▼
                                       Docker Hub
                                            │
                                    ┌───────┴───────┐
                                    ▼               ▼
                                Terraform        Ansible
                           (Create Namespace) (Config Env/Folders)
                                    │               │
                                    └───────┬───────┘
                                            ▼
                                   Kubernetes Cluster (Minikube)
                                   ┌──────────────────────────┐
                                   │  Namespace: food-system  │
                                   │                          │
                                   │  [Backend Pods (Go)] ◀┐  │
                                   │          ▲            │  │
                                   │      ClusterIP        │  │
                                   │                       │  │
                                   │  [Frontend Pods (React)] │
                                   │          ▲               │
                                   │       NodePort           │
                                   └──────────┼───────────────┘
                                              │
                          ┌───────────────────┴────┐
                          ▼                        ▼
                     Prometheus  ─────────────▶ Grafana
                  (Scrape /metrics)           (Dashboard)
```

---

## 📁 3. โครงสร้าง Repository (Monorepo)

```bash
food-ordering-system/
├── frontend/               # React (Vite) App
│   ├── src/
│   ├── package.json
│   ├── .dockerignore
│   └── Dockerfile          # Nginx 1.27-alpine, non-root user
├── backend/                # Go (Gin) API + Prometheus metrics
│   ├── main.go
│   ├── go.mod
│   ├── .dockerignore
│   └── Dockerfile          # alpine:3.21, non-root user, HEALTHCHECK
├── terraform/              # โค้ดสร้าง K8s Namespace
│   ├── main.tf             # kubernetes_namespace_v1 (non-deprecated)
│   ├── versions.tf         # Lock provider versions
│   ├── variables.tf        # Input variables
│   └── outputs.tf          # Output values
├── ansible/                # โค้ดตั้งค่า Environment / Deploy
│   ├── inventory
│   ├── playbook.yml        # Entry point ใช้ Roles
│   └── roles/
│       ├── k8s-deploy/     # Role: deploy app manifests
│       └── monitoring/     # Role: deploy Prometheus + Grafana
├── k8s/                    # Kubernetes Manifests
│   ├── backend.yaml        # Deployment & Service (ClusterIP) + probes + limits
│   ├── frontend.yaml       # Deployment & Service (NodePort:30080) + probes + limits
│   ├── ingress.yaml        # Ingress Controller routing
│   ├── hpa.yaml            # Horizontal Pod Autoscaler
│   └── network-policy.yaml # Zero-trust Network Policies
├── monitoring/             # Config & Deployment สำหรับ Prometheus และ Grafana
│   ├── prometheus.yml          # Prometheus scrape config
│   ├── prometheus-deployment.yaml  # Prometheus K8s Deployment
│   ├── grafana-dashboard.json  # Grafana Dashboard (5 panels)
│   └── grafana-deployment.yaml # Grafana K8s Deployment (NodePort:30300)
├── Jenkinsfile             # CI/CD Pipeline (8 stages incl. Trivy scan)
└── README.md
```

---

## ⚙️ 4. สิ่งที่ต้องติดตั้งก่อน (Prerequisites)

| Tool | หน้าที่ |
|------|---------|
| Docker | สร้างและรัน Container (Frontend/Backend) |
| Docker Hub | Registry เก็บ images (`gowitphooang/food-backend`, `gowitphooang/food-frontend`) |
| Jenkins | ระบบจัดการ CI/CD Pipeline (8 stages) |
| Terraform | Provision K8s Namespace ด้วย `kubernetes_namespace_v1` |
| Ansible | Deploy Application + Monitoring Stack อัตโนมัติ |
| Minikube / kubectl | รัน Kubernetes Cluster จำลอง |
| Prometheus & Grafana | ระบบ Monitoring + Dashboard (5 panels) |
| Trivy | Security scanning สำหรับ Docker images |

---

## 🔄 5. CI/CD Pipeline (Jenkins)

ทำงานอัตโนมัติเมื่อเกิด Event `git push` ไปที่ branch `main` โดยแบ่งเป็น **8 Stages** ดังนี้:

1. **Checkout:** ดึงโค้ดล่าสุดจาก GitHub ผ่าน Webhook Trigger
2. **Build:** `go build` (Backend) และ `npm ci && npm run build` (Frontend)
3. **Test:** รัน `go test -v ./...` Unit Test ทั้งหมด
4. **Docker Build:** สร้าง Docker Images 2 ตัว tag ด้วย `BUILD_ID` สำหรับ traceability
5. **Security Scan:** ใช้ **Trivy** scan หา CRITICAL vulnerabilities ก่อน push
6. **Push to Hub:** Push ขึ้น Docker Hub (`gowitphooang/food-backend`, `gowitphooang/food-frontend`)
7. **Infrastructure (Terraform):** รัน `terraform apply` สร้าง K8s Namespace
8. **Configure (Ansible):** รัน `ansible-playbook` deploy monitoring + verify rollout
9. **Deploy to Kubernetes:** `kubectl apply` + `kubectl rollout status` verify สำเร็จ

---

## 🏗️ 6. Infrastructure as Code (IaC)

- **Terraform:** ทำหน้าที่จัดการโครงสร้างพื้นฐาน โดยโปรเจกต์นี้ใช้สำหรับ Provision `Namespace` ชื่อ `food-system` บน Kubernetes เพื่อแบ่งแยกพื้นที่ให้เป็นระเบียบ
- **Ansible:** ทำหน้าที่ตั้งค่า Environment เช่น การตรวจสอบสถานะของ Minikube Cluster และเตรียม Directory ภายในเครื่องสำหรับ Mount Volume ให้ระบบ Monitoring

---

## ☸️ 7. Kubernetes Deployment

แอปพลิเคชันถูก Deploy แบบ High Availability (HA) เบื้องต้น:

- **Backend:** 
  - `Replicas: 2` (รับโหลดได้มากขึ้น)
  - `Service: ClusterIP` (ให้เฉพาะแอปใน Cluster คุยกัน ปลอดภัยจากภายนอก)
- **Frontend:**
  - `Replicas: 2`
  - `Service: NodePort` (เปิดพอร์ต 30080 ให้ User เข้าหน้าเว็บสั่งอาหารได้)

---

## 📊 8. Monitoring System

Backend (Go) จะเปิด Endpoint `GET /metrics` ไว้ให้ Prometheus เข้ามาดึงข้อมูลทุกๆ 15 วินาที โดยจะนำไปแสดงผลบน **Grafana Dashboard** 

**Panels ที่แสดงใน Dashboard (5 Panels):**
1. **Request Rate:** จำนวน requests/sec แบ่งตาม method และ path
2. **Error Rate (5xx):** อัตราการเกิด Server Error
3. **Service Uptime:** สถานะว่าแอปพลิเคชันยังทำงานอยู่หรือไม่ (1 = Up, 0 = Down)
4. **Orders Created:** จำนวน Food Orders สะสมทั้งหมด (Business Metric)
5. **API Latency (P95/P50):** ระยะเวลา response ที่ percentile ต่างๆ

**เข้าถึง Monitoring:**
- **Prometheus:** `http://$(minikube ip):30090` (ถ้าใช้ NodePort)
- **Grafana:** `http://$(minikube ip):30300` (Login: admin / admin123)

---

## 🧪 9. API Specification (Backend)

| Method | Endpoint | หน้าที่ |
|--------|----------|---------|
| `GET` | `/api/menu` | แสดงรายการอาหาร |
| `POST` | `/api/order` | สร้างคำสั่งซื้อ |
| `GET` | `/metrics` | สำหรับ Prometheus Scrape (Monitoring) |
| `GET` | `/health` | ตรวจสอบสถานะ Backend (Health Check) |

---

## 🏃 10. วิธีทดสอบรันแบบ Manual (Quick Start)

**1. Clone Project**
```bash
git clone https://github.com/[username]/food-ordering-system.git
cd food-ordering-system
```

**2. รัน Backend (Local)**
```bash
cd backend
go run main.go
# Backend รันที่พอร์ต http://localhost:8080
```

**3. รัน Frontend (Local)**
```bash
cd frontend
npm install
npm run dev
# Frontend รันที่พอร์ต http://localhost:5173
```
