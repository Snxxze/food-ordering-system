# Jenkins Setup

## วิธีรัน Jenkins

```bash
cd jenkins-setup
docker-compose up -d
```

รอประมาณ **30 วินาที** แล้วเปิดเบราว์เซอร์:
👉 http://localhost:9090

## รับรหัสผ่านครั้งแรก

```bash
docker exec devops-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## หยุด Jenkins

```bash
docker-compose down
```
