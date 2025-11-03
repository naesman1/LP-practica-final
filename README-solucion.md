# 🚀 Práctica Final - Liberando Productos (Solución)

Este repositorio contiene la **solución a la práctica final del módulo “Liberando Productos”**.  
El proyecto original (un simple servidor **FastAPI**) ha sido mejorado para incluir un pipeline completo de **CI/CD**, despliegue en **Kubernetes**, monitoreo con **Prometheus**, alertas con **Alertmanager** y visualización con **Grafana**.

---

## 📚 Índice

1. [Arquitectura de la Solución](#-arquitectura-de-la-solución)  
2. [Entregables y Guía de Reproducción](#-entregables-y-guía-de-reproducción)  
   1. [Pre-requisitos](#1-pre-requisitos)  
   2. [Modificaciones de la Aplicación](#2-modificaciones-de-la-aplicación)  
   3. [Pipeline de CI/CD (GitHub Actions)](#3-pipeline-de-cicd-github-actions)  
   4. [Despliegue en Kubernetes](#4-despliegue-en-kubernetes)  
   5. [Configuración de Alertas (Prometheus + Slack)](#5-configuración-de-alertas-prometheus--slack)  
   6. [Dashboard de Grafana](#6-dashboard-de-grafana)  
3. [📷 Galería de Resultados](#-galería-de-resultados)  
4. [🧾 Créditos](#-créditos)

---

## 🏗️ Arquitectura de la Solución

El flujo de trabajo implementado es el siguiente:

1. **CI (GitHub Actions):** En cada push a `main`, se ejecutan tests unitarios (`pytest`).  
2. **CD (GitHub Actions):** Si los tests pasan, se construye la imagen Docker y se publica en **GitHub Container Registry (GHCR)**.  
3. **Despliegue (Kubernetes):** Se usa un clúster local de **Minikube** para desplegar la aplicación con los manifiestos en `k8s/`.  
4. **Monitoreo (Prometheus):** Se instala la stack `kube-prometheus-stack` (vía Helm), que descubre y “raspa” automáticamente las métricas expuestas.  
5. **Alertas (Alertmanager):** Una regla personalizada vigila el uso de CPU. Si supera el 80% del límite, **Alertmanager** envía una alerta *CRITICAL* a **Slack**.  
6. **Visualización (Grafana):** Un dashboard personalizado (`grafana/dashboard.json`) muestra métricas en tiempo real.

---

## 🧩 Entregables y Guía de Reproducción

A continuación se detallan los pasos para reproducir la solución completa.

### 1. ⚙️ Pre-requisitos

Asegúrate de tener instalados en tu entorno (se recomienda **WSL2**):

```bash
minikube
kubectl
helm
docker  # (vía Docker Desktop)
python3 y venv  # (para pruebas locales)
```

---

### 2. 🧠 Modificaciones de la Aplicación

El código fuente original fue modificado para cumplir los nuevos requisitos:

- **Nuevo endpoint `/bye`:** Añadido en `src/application/app.py`.  
- **Nueva métrica:** Contador de Prometheus `bye_requests_total`.  
- **Nuevo test unitario:** En `src/tests/app_test.py` para validar el nuevo endpoint.

---

### 3. 🧪 Pipeline de CI/CD (GitHub Actions)

El archivo [`./github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) define el pipeline:

#### 🧩 Job `test`
- Instala Python 3.11.  
- Instala dependencias.  
- Ejecuta `pytest --cov`.

#### 🚀 Job `build-and-push`
- Inicia sesión en **GHCR**.  
- Construye la imagen Docker (basada en `python:3.11-slim-bullseye`).  
- Etiqueta y sube la imagen al registro.  

> **Nota:** Para usar el pipeline en tu fork, habilita los *permissions* de escritura para Actions en tu repositorio.

---

### 4. ☸️ Despliegue en Kubernetes

Sigue los pasos para desplegar toda la infraestructura en **Minikube**.

#### 🪄 Paso 1: Iniciar Minikube

```bash
minikube start --driver=docker
```

#### 🪄 Paso 2: Instalar la Stack de Monitoreo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack   --namespace monitoring --create-namespace
```

> ⏱️ Espera 2–3 minutos a que todos los pods en `monitoring` estén en estado **Running**.

#### 🪄 Paso 3: Crear Secreto de GHCR

```bash
kubectl create secret generic ghcr-creds   --from-file=.dockerconfigjson=${HOME}/.docker/config.json   --type=kubernetes.io/dockerconfigjson
```

> Asegúrate de haber hecho antes `docker login ghcr.io`.

#### 🪄 Paso 4: Desplegar la Aplicación y Reglas

```bash
kubectl apply -f k8s/
```

Esto creará:

- `k8s/deployment.yml` → Despliegue de la app (límite CPU: 200m).  
- `k8s/service.yml` → Servicio con puertos 8081 y 8000.  
- `k8s/servicemonitor.yml` → Descubrimiento por Prometheus.  
- `k8s/prometheus-rule.yml` → Regla de alerta por CPU.

---

### 5. 🔔 Configuración de Alertas (Prometheus + Slack)

#### 🪄 Paso 1: Configurar Alertmanager

Edita `alertmanager.yaml` para incluir tu **Webhook de Slack**:

```yaml
receivers:
  - name: "slack"
    slack_configs:
      - api_url: "https://hooks.slack.com/services/TU_TOKEN_AQUI"
        channel: "#mi-canal-de-alertas"
```

Aplica la configuración:

```bash
kubectl --namespace monitoring create secret generic alertmanager-prometheus-kube-prometheus-alertmanager   --from-file=alertmanager.yaml=alertmanager.yaml   --dry-run=client -o yaml | kubectl apply -f -
```

Reinicia Alertmanager:

```bash
kubectl --namespace monitoring rollout restart statefulset/alertmanager-prometheus-kube-prometheus-alertmanager
```

#### 🧪 Paso 2: Probar la Alerta de CPU

```bash
kubectl run stress-tester --image=busybox:1.28 --rm -it -- /bin/sh
```

Dentro del pod:
```bash
for i in $(seq 1 10); do
  while true; do wget -q -O- http://simple-server-service:8081/bye; done &
done

while true; do wget -q -O- http://simple-server-service:8081/bye; done
```

> 🔥 Después de 1 minuto, la alerta **HighCpuUsage** pasará a *FIRING* y recibirás una notificación en Slack.  
> Al detener el pod (Ctrl+C), recibirás la alerta *RESOLVED*.

---

### 6. 📊 Dashboard de Grafana

El dashboard final se encuentra en [`grafana/dashboard.json`](grafana/dashboard.json).

#### 🪄 Paso 1: Acceder a Grafana

```bash
kubectl --namespace monitoring get secrets prometheus-grafana   -o jsonpath="{.data.admin-password}" | base64 -d ; echo

kubectl --namespace monitoring port-forward   $(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname) 3000:3000
```

Accede en el navegador:  
👉 [http://localhost:3000](http://localhost:3000)  
*(Usuario: `admin`, Contraseña: la obtenida arriba)*

#### 🪄 Paso 2: Importar el Dashboard

En Grafana:

1. Ve a **Dashboards → New → Import**.  
2. Sube o pega el contenido del archivo `grafana/dashboard.json`.

---

### ⚠️ Problema Común: Desfase de Hora (Clock Drift)

> **Síntoma:** Grafana no muestra datos, aunque Prometheus los tenga.

📅 **Solución:** Ajustar el rango de tiempo manualmente en Grafana:

```
From: 2025-11-03 02:00:00  
To:   2025-11-03 03:00:00
```
O selecciona un rango amplio como *Last 2 days*.

---

## 📷 Galería de Resultados

| Entregable | Imagen |
|-------------|--------|
| 🧱 Aplicación desplegada | ![App Desplegada](./images/app-deploy.png) |
| ☸️ ArgoCD (Pipeline CD) | ![ArgoCD](./images/argocd.png) |
| 🧪 SonarCloud | ![SonarCloud](./images/sonar.png) |
| 🛡️ Snyk Security Scan | ![Snyk](./images/snyk.png) |
| 📊 Dashboard Grafana | ![Grafana](./images/grafana.png) |
| 🔔 Alerta Slack | ![Slack Alert](./images/slack-alert.png) |

🎥 **Video de presentación (YouTube):**  
👉 [Enlace al video de la práctica](https://youtube.com/placeholder)

---

## 🧾 Créditos

Desarrollado por **Miguel Ángel Narvaiz Eslava**  
📘 Módulo: *Liberando Productos – KeepCoding DevOps Bootcamp*  
🧑‍💻 Tecnologías: FastAPI · Docker · GitHub Actions · Kubernetes · Prometheus · Alertmanager · Grafana
