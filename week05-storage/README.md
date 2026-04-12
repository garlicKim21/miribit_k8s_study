# 5주차: Kubernetes Storage

## 학습 목표

- Kubernetes Volume의 개념과 종류를 이해합니다.
- PersistentVolume(PV)과 PersistentVolumeClaim(PVC)을 학습합니다.
- StorageClass를 통한 동적 프로비저닝을 이해합니다.
- 실제 환경에서 상태 저장 애플리케이션을 배포합니다.

---

## 1. 컨테이너 스토리지의 문제

### 1.1 컨테이너의 휘발성

컨테이너는 기본적으로 **휘발성(Ephemeral)** 스토리지를 사용합니다:

```
┌───────────────── Container Lifecycle ─────────────────┐
│                                                       │
│   Container Start → Write Data → Container Crash      │
│                         │                             │
│                    [Data Lost!]                       │
│                                                       │
│   New Container Start → No Data                       │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**문제점:**
- 컨테이너 재시작 시 모든 데이터 손실
- Pod 간 데이터 공유 불가
- 상태 저장 애플리케이션(DB 등) 운영 어려움

### 1.2 Volume의 필요성

```
┌───────────────── With Volume ─────────────────────────┐
│                                                       │
│   Container Start → Write to Volume → Container Crash │
│                         │                             │
│                    [Volume persists]                  │
│                                                       │
│   New Container Start → Read from Volume → Data OK!   │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## 2. Volume 종류

### 2.1 emptyDir

Pod의 생명주기와 함께하는 임시 볼륨:

```yaml
# examples/pod-emptydir.yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
spec:
  containers:
  - name: content-creator
    image: busybox:1.36
    command: ['sh', '-c', 'echo "<h1>Hello from emptyDir!</h1>" > /usr/share/nginx/html/index.html && sleep 3600']
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html

  - name: web
    image: nginx:1.27
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html

  volumes:
  - name: shared-data
    emptyDir: {}
```

```
┌──────────────────── Pod ────────────────────┐
│                                             │
│  ┌───────────────────┐  ┌────────────────┐  │
│  │  content-creator  │  │  web (nginx)   │  │
│  │  (busybox)        │  │  :80           │  │
│  │                   │  │                │  │
│  │  index.html 생성  │  │  웹 페이지 서빙 │  │
│  └────────┬──────────┘  └───────┬────────┘  │
│           │                     │           │
│           └──────────┬──────────┘           │
│                      │                      │
│               ┌──────▼──────┐               │
│               │  emptyDir   │               │
│               │  (Volume)   │               │
│               └─────────────┘               │
│                                             │
└─────────────────────────────────────────────┘
```

**특징:**
- Pod 시작 시 빈 디렉토리 생성
- Pod 삭제 시 함께 삭제
- 같은 Pod 내 컨테이너 간 데이터 공유
- 임시 캐시, 중간 처리 결과 저장에 적합

**메모리 기반 emptyDir:**
```yaml
volumes:
- name: cache
  emptyDir:
    medium: Memory  # RAM에 저장 (더 빠름)
    sizeLimit: 100Mi
```

### 2.2 hostPath

노드의 파일 시스템을 마운트:

```yaml
# examples/pod-hostpath.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-data
      mountPath: /data
      readOnly: true

  volumes:
  - name: host-data
    hostPath:
      path: /var/log  # 노드의 실제 경로
      type: Directory
```

```
┌────────── Node ──────────┐
│                          │
│  ┌────── Pod ──────┐     │
│  │                 │     │
│  │  Container      │     │
│  │   /data ◄───────┼─────┼─── /var/log (Node)
│  │                 │     │
│  └─────────────────┘     │
│                          │
└──────────────────────────┘
```

**hostPath type:**
| Type | 설명 |
|------|------|
| `Directory` | 디렉토리가 존재해야 함 |
| `DirectoryOrCreate` | 없으면 생성 |
| `File` | 파일이 존재해야 함 |
| `FileOrCreate` | 없으면 생성 |
| `Socket` | Unix 소켓이 존재해야 함 |

**주의사항:**
- 특정 노드에 종속
- 보안 위험 (호스트 파일 시스템 접근)
- 주로 DaemonSet에서 노드 로그/메트릭 수집에 사용

### 2.3 ConfigMap과 Secret

ConfigMap과 Secret은 설정 데이터를 컨테이너에 주입하는 리소스입니다.
Pod에서 사용하는 방법은 크게 두 가지입니다:

1. **환경 변수**로 주입
2. **볼륨 마운트**로 파일 형태로 주입

```
┌──────────────────── Pod ────────────────────┐
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  Container                            │  │
│  │                                       │  │
│  │  환경 변수: APP_ENV=production         │  ← env / envFrom
│  │  환경 변수: APP_PORT=8080              │  │
│  │                                       │  │
│  │  /etc/config/app.properties (파일)     │  ← volumeMounts
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

#### ConfigMap — 비민감 설정 데이터

```yaml
# examples/configmap-pod.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  APP_ENV: "production"
  APP_PORT: "8080"
  app.properties: |
    database.host=db.example.com
    database.port=5432
    database.name=myapp
---
apiVersion: v1
kind: Pod
metadata:
  name: configmap-demo
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ['sh', '-c', 'echo "APP_ENV=$APP_ENV" && echo "APP_PORT=$APP_PORT" && echo "---" && cat /etc/config/app.properties && sleep 3600']
    # 방법 1: 환경 변수로 주입
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: demo-config
          key: APP_ENV
    - name: APP_PORT
      valueFrom:
        configMapKeyRef:
          name: demo-config
          key: APP_PORT
    # 방법 2: 볼륨 마운트로 파일 주입
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: demo-config
      items:
      - key: app.properties
        path: app.properties
```

#### Secret — 민감 데이터 (비밀번호, 토큰 등)

ConfigMap과 사용법이 동일하지만, 데이터가 Base64로 인코딩됩니다.
`stringData`를 사용하면 평문으로 작성할 수 있습니다 (apply 시 자동 인코딩).

```yaml
# examples/secret-pod.yaml
apiVersion: v1
kind: Secret
metadata:
  name: demo-secret
type: Opaque
stringData:
  username: admin
  password: "S3cur3P@ssw0rd!"
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ['sh', '-c', 'echo "DB_USER=$DB_USER" && echo "---" && ls /etc/secrets/ && cat /etc/secrets/username && sleep 3600']
    # 방법 1: 환경 변수로 주입
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: demo-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: demo-secret
          key: password
    # 방법 2: 볼륨 마운트 (각 키가 개별 파일로 생성)
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: demo-secret
```

> **참고:** Base64는 인코딩이지 암호화가 아닙니다. 프로덕션에서는 RBAC 제한과 etcd 암호화를 함께 적용해야 합니다.

---

## 3. PersistentVolume (PV)

### 3.1 PV란?

클러스터 레벨의 스토리지 리소스:

```
┌──────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │            PersistentVolume (PV)                │ │
│  │                                                 │ │
│  │  - 클러스터 관리자가 프로비저닝                   │ │
│  │  - 실제 스토리지와 연결                          │ │
│  │  - 클러스터 레벨 리소스 (namespace 무관)         │ │
│  │                                                 │ │
│  └─────────────────────────────────────────────────┘ │
│                         │                            │
│              ┌──────────▼───────────┐                │
│              │   실제 스토리지       │                │
│              │  (NFS, AWS EBS,      │                │
│              │   Local Disk 등)     │                │
│              └──────────────────────┘                │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 3.2 PV 정의

```yaml
# examples/pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

### 3.3 Access Modes

| Mode | 약어 | 설명 |
|------|------|------|
| `ReadWriteOnce` | RWO | 단일 노드에서 읽기/쓰기 |
| `ReadOnlyMany` | ROX | 여러 노드에서 읽기 전용 |
| `ReadWriteMany` | RWX | 여러 노드에서 읽기/쓰기 |
| `ReadWriteOncePod` | RWOP | 단일 Pod에서 읽기/쓰기 |

### 3.4 Reclaim Policy

PVC 삭제 시 PV의 동작:

| Policy | 설명 |
|--------|------|
| `Retain` | PV와 데이터 유지 (수동 정리) |
| `Delete` | PV와 데이터 함께 삭제 |
| `Recycle` | 데이터 삭제 후 재사용 (deprecated) |

---

## 4. PersistentVolumeClaim (PVC)

### 4.1 PVC란?

사용자(개발자)가 스토리지를 요청하는 방법:

```
┌────────────────────── 워크플로우 ──────────────────────┐
│                                                       │
│  Developer                   Cluster Admin            │
│     │                             │                   │
│     │ 1. PVC 생성                 │                   │
│     │ (10Gi 필요)                 │ PV 생성           │
│     │     │                       │ (10Gi 제공)       │
│     ▼     │                       ▼                   │
│  ┌──────────┐                ┌──────────┐             │
│  │   PVC    │───Binding────→│   PV     │             │
│  │  10Gi   │                │  10Gi    │             │
│  └────┬─────┘                └──────────┘             │
│       │                                               │
│       │ 2. Pod에서 PVC 사용                            │
│       ▼                                               │
│  ┌──────────┐                                         │
│  │   Pod    │                                         │
│  └──────────┘                                         │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### 4.2 PVC 정의

```yaml
# examples/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

### 4.3 PVC를 Pod에서 사용

```yaml
# examples/pod-with-pvc.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: my-storage
      mountPath: /usr/share/nginx/html

  volumes:
  - name: my-storage
    persistentVolumeClaim:
      claimName: my-pvc
```

### 4.4 PV-PVC 바인딩 조건

PVC가 PV에 바인딩되려면:

1. **Capacity**: PV >= PVC 요청 용량
2. **Access Mode**: PV가 PVC의 access mode 지원
3. **StorageClass**: 동일한 StorageClass (또는 빈 문자열)
4. **Selector**: PVC selector와 PV label 일치 (있는 경우)

```
PVC 요청:                  PV 제공:
- 5Gi                     - 10Gi ✓ (충족)
- ReadWriteOnce           - ReadWriteOnce ✓
- storageClassName: fast  - storageClassName: fast ✓

→ 바인딩 성공!
```

---

## 5. StorageClass와 동적 프로비저닝

### 5.1 정적 vs 동적 프로비저닝

```
┌────────────── 정적 프로비저닝 ──────────────┐
│                                            │
│  1. Admin: PV 생성 (수동)                   │
│  2. User: PVC 생성                          │
│  3. Kubernetes: PV-PVC 바인딩               │
│                                            │
│  단점: 매번 관리자가 PV를 미리 만들어야 함    │
│                                            │
└────────────────────────────────────────────┘

┌────────────── 동적 프로비저닝 ──────────────┐
│                                            │
│  1. Admin: StorageClass 정의 (한 번)        │
│  2. User: PVC 생성                          │
│  3. Kubernetes: PV 자동 생성 및 바인딩       │
│                                            │
│  장점: 필요할 때 자동으로 스토리지 생성       │
│                                            │
└────────────────────────────────────────────┘
```

### 5.2 StorageClass란?

StorageClass는 **Provisioner(프로비저너)**를 지정하여 동적 프로비저닝을 가능하게 합니다.

StorageClass의 주요 필드:

| 필드 | 설명 |
|------|------|
| `provisioner` | PV를 자동 생성하는 프로비저너 지정 |
| `parameters` | 프로비저너별 세부 설정 (디스크 타입 등) |
| `reclaimPolicy` | PVC 삭제 시 PV 처리 방식 (`Delete`/`Retain`) |
| `volumeBindingMode` | PV 바인딩 시점 (`Immediate`/`WaitForFirstConsumer`) |
| `allowVolumeExpansion` | PVC 용량 확장 허용 여부 |

```
┌─────────────── StorageClass 역할 ───────────────┐
│                                                  │
│   StorageClass         Provisioner               │
│   ┌──────────┐        ┌──────────────┐           │
│   │ name     │──────→ │ PV 자동 생성  │           │
│   │ provisioner │     │ (디스크 할당)  │           │
│   │ parameters  │     └──────┬───────┘           │
│   └──────────┘               │                   │
│        ▲                     ▼                   │
│        │              ┌──────────────┐           │
│   PVC에서 지정         │  PV (자동)    │           │
│                       └──────────────┘           │
│                                                  │
└──────────────────────────────────────────────────┘
```

> **참고:** `kubernetes.io/no-provisioner`는 이름과 달리 동적 프로비저닝을 **지원하지 않습니다**.
> 이미 존재하는 로컬 볼륨을 PV로 등록할 때만 사용하며, PVC를 만들어도 PV가 자동 생성되지 않습니다.

### 5.3 local-path-provisioner 설치 (실습 환경)

우리 실습 환경은 온프레미스 VM 기반 kubeadm 클러스터이므로,
클라우드 스토리지(EBS, PD 등)를 사용할 수 없습니다.

[Rancher local-path-provisioner](https://github.com/rancher/local-path-provisioner)는
kubeadm 클러스터에서 간단히 설치할 수 있는 동적 프로비저너입니다.
PVC를 생성하면 노드의 로컬 디스크(`/opt/local-path-provisioner`)에 자동으로 PV를 생성해줍니다.

```
┌──────────────── 동적 프로비저닝 흐름 ────────────────┐
│                                                     │
│  1. User: PVC 생성 (storageClassName: local-path)   │
│                    │                                │
│                    ▼                                │
│  2. local-path-provisioner가 감지                    │
│                    │                                │
│                    ▼                                │
│  3. 노드의 /opt/local-path-provisioner/ 에           │
│     디렉토리 자동 생성                                │
│                    │                                │
│                    ▼                                │
│  4. hostPath PV 자동 생성 및 PVC 바인딩              │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**설치:**

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.35/deploy/local-path-storage.yaml

# 설치 확인
kubectl -n local-path-storage get pod
kubectl get storageclass
```

설치하면 `local-path`라는 StorageClass가 생성됩니다.

**동적 프로비저닝 실습:**

```yaml
# examples/local-path-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

```yaml
# examples/pod-with-local-path.yaml
apiVersion: v1
kind: Pod
metadata:
  name: local-path-pod
spec:
  containers:
  - name: app
    image: nginx:1.27
    ports:
    - containerPort: 80
    volumeMounts:
    - name: local-storage
      mountPath: /usr/share/nginx/html

  volumes:
  - name: local-storage
    persistentVolumeClaim:
      claimName: local-path-pvc
```

> **참고:** local-path-provisioner는 노드 로컬 디스크를 사용하므로 데이터 복제가 없습니다.
> 학습/개발 환경에 적합하며, 프로덕션에서는 CSI 드라이버 기반 스토리지를 사용합니다.

### 5.4 클라우드 환경의 StorageClass

실제 프로덕션 환경에서는 클라우드 CSI 드라이버를 provisioner로 사용합니다:

```yaml
# AWS EBS
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
```

```yaml
# GCP Persistent Disk
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
volumeBindingMode: WaitForFirstConsumer
```

| 환경 | Provisioner | 특징 |
|------|-------------|------|
| 온프레미스 (실습) | `rancher.io/local-path` | 노드 로컬 디스크, 복제 없음 |
| AWS | `ebs.csi.aws.com` | EBS 볼륨 자동 생성 |
| GCP | `pd.csi.storage.gke.io` | Persistent Disk 자동 생성 |
| Azure | `disk.csi.azure.com` | Azure Disk 자동 생성 |

### 5.5 기본 StorageClass

```bash
# 기본 StorageClass 확인
kubectl get sc

# local-path를 기본 StorageClass로 설정
kubectl patch sc local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## 6. 실습

### 6.1 emptyDir 실습

```bash
# Pod 생성 (busybox + nginx 2개 컨테이너)
kubectl apply -f examples/pod-emptydir.yaml

# Pod 상태 확인 (2/2 Running 확인)
kubectl get pod emptydir-pod

# busybox가 생성한 웹 페이지를 nginx가 서빙하는지 확인
kubectl exec emptydir-pod -c web -- curl -s localhost

# 포트포워딩으로 브라우저에서 확인
kubectl port-forward emptydir-pod 8080:80
# 브라우저에서 http://localhost:8080 접속
```

### 6.2 PV/PVC 실습

```bash
# 노드에서 디렉토리 생성 (hostPath용)
# Worker 노드에 SSH 접속 후:
# sudo mkdir -p /mnt/data

# PV 생성
kubectl apply -f examples/pv.yaml

# PV 상태 확인
kubectl get pv

# PVC 생성
kubectl apply -f examples/pvc.yaml

# 바인딩 확인
kubectl get pv,pvc

# Pod 생성
kubectl apply -f examples/pod-with-pvc.yaml

# Pod에서 데이터 쓰기
kubectl exec -it pvc-pod -- bash -c "echo 'Hello PV!' > /usr/share/nginx/html/index.html"

# 확인
kubectl exec pvc-pod -- cat /usr/share/nginx/html/index.html
```

### 6.3 local-path-provisioner 동적 프로비저닝 실습

```bash
# local-path-provisioner 설치
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.35/deploy/local-path-storage.yaml

# 설치 확인 (Provisioner Pod가 Running 상태인지 확인)
kubectl -n local-path-storage get pod

# StorageClass 확인 (local-path가 보여야 함)
kubectl get sc

# PVC 생성 — PV를 직접 만들지 않아도 자동 생성됨!
kubectl apply -f examples/local-path-pvc.yaml

# PVC 상태 확인 (아직 Pending — Pod가 스케줄되어야 바인딩)
kubectl get pvc local-path-pvc

# Pod 생성
kubectl apply -f examples/pod-with-local-path.yaml

# PVC가 Bound 상태로 변경되고 PV가 자동 생성된 것 확인
kubectl get pv,pvc

# 데이터 쓰기
kubectl exec local-path-pod -- sh -c 'echo "<h1>Dynamic Provisioning!</h1>" > /usr/share/nginx/html/index.html'

# 확인
kubectl exec local-path-pod -- curl -s localhost

# 정리
kubectl delete -f examples/pod-with-local-path.yaml
kubectl delete -f examples/local-path-pvc.yaml
```

> **핵심 포인트:** 정적 프로비저닝(6.2)에서는 PV를 먼저 만들어야 했지만,
> 동적 프로비저닝에서는 PVC만 만들면 PV가 **자동으로** 생성됩니다.

### 6.4 ConfigMap 실습

```bash
# ConfigMap + Pod 생성
kubectl apply -f examples/configmap-pod.yaml

# Pod 상태 확인
kubectl get pod configmap-demo

# 환경 변수 확인
kubectl exec configmap-demo -- sh -c 'echo APP_ENV=$APP_ENV && echo APP_PORT=$APP_PORT'
# 출력: APP_ENV=production
#       APP_PORT=8080

# 마운트된 설정 파일 확인
kubectl exec configmap-demo -- cat /etc/config/app.properties
# 출력: database.host=db.example.com ...

# 정리
kubectl delete -f examples/configmap-pod.yaml
```

### 6.5 Secret 실습

```bash
# Secret + Pod 생성
kubectl apply -f examples/secret-pod.yaml

# Pod 상태 확인
kubectl get pod secret-demo

# 환경 변수로 주입된 값 확인
kubectl exec secret-demo -- sh -c 'echo DB_USER=$DB_USER'
# 출력: DB_USER=admin

# 볼륨 마운트된 파일 확인 (각 키가 개별 파일)
kubectl exec secret-demo -- ls /etc/secrets/
# 출력: password  username

kubectl exec secret-demo -- cat /etc/secrets/username
# 출력: admin

# Secret 값 직접 조회 (Base64 디코딩)
kubectl get secret demo-secret -o jsonpath='{.data.username}' | base64 -d
# 출력: admin

# 정리
kubectl delete -f examples/secret-pod.yaml
```

### 6.6 MySQL with PVC 실습

```bash
# MySQL 배포
kubectl apply -f examples/mysql-deployment.yaml

# 데이터베이스 확인
kubectl exec -it deploy/mysql -- mysql -uroot -ppassword -e "SHOW DATABASES;"

# 데이터베이스 생성
kubectl exec -it deploy/mysql -- mysql -uroot -ppassword -e "CREATE DATABASE testdb;"

# Pod 삭제 후 재생성
kubectl delete pod -l app=mysql

# 데이터 유지 확인
kubectl exec -it deploy/mysql -- mysql -uroot -ppassword -e "SHOW DATABASES;"
```

---

## 7. 실습 정리

### 7.1 리소스 정리

```bash
kubectl delete -f examples/
```

### 7.2 PV 상태 확인

```
Status    설명
------    ----
Available PVC와 바인딩되지 않음
Bound     PVC와 바인딩됨
Released  PVC 삭제됨, 재사용 대기 (Retain 정책)
Failed    동적 프로비저닝 실패
```

### 7.3 오늘 배운 내용

1. **Volume**: 컨테이너의 휘발성 스토리지 문제 해결
2. **emptyDir/hostPath**: 기본 볼륨 타입
3. **PersistentVolume**: 클러스터 레벨 스토리지 리소스
4. **PersistentVolumeClaim**: 사용자의 스토리지 요청
5. **StorageClass**: 동적 프로비저닝
6. **local-path-provisioner**: kubeadm 클러스터에서 동적 프로비저닝 체험

### 7.4 다음 주차 예고

6주차에서는 Kubernetes 운영을 학습합니다:
- ConfigMap과 Secret
- Resource Management (requests/limits)
- 헬스체크 (Liveness/Readiness Probe)
- 롤링 업데이트와 롤백

---

## 참고 자료

- [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [Rancher local-path-provisioner](https://github.com/rancher/local-path-provisioner)
