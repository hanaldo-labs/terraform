# Wireguard 서버

wg-easy v15 기반 WireGuard VPN 서버를 AWS EC2에 구성한다.

- EC2 Amazon Linux 2023 ARM64
- Docker Compose
- [wg-easy v15](https://wg-easy.github.io/wg-easy/v15.3/examples/tutorials/basic-installation/)

## 구성 개요

- public inbound는 WireGuard UDP 포트만 허용한다.
- SSH 포트는 열지 않고 AWS Systems Manager Session Manager로 서버에 접근한다.
- wg-easy UI는 public에 노출하지 않고 WireGuard VPN 또는 SSM port forwarding으로만 접근한다.
- WireGuard EC2는 private subnet의 NAT 인스턴스 역할도 수행할 수 있다.
- wg-easy 컨테이너 로그는 CloudWatch Logs로 전송한다.

## 사전 조건

1. `aws-common` 프로젝트가 먼저 적용되어 있어야 한다.
2. `aws-common` remote state에 아래 output이 있어야 한다.
   - `vpc_id`
   - `public_subnet_ids`
   - `private_route_table_id`
3. `aws-common`에서 생성한 `common-key` EC2 key pair가 존재해야 한다.
4. `init_password` 값을 설정해야 한다.

## 프로비저닝

```bash
terraform init
terraform apply
```

## 접근 방식

### 서버 관리

WireGuard 서버 자체 관리는 SSH가 아니라 Session Manager를 사용한다.

```bash
aws ssm start-session --target <instance-id>
```

EC2 security group은 SSH ingress를 열지 않는다.

### 초기 client 생성

초기에는 VPN client config가 없으므로 SSM port forwarding으로 wg-easy UI에 접근한다.

```bash
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=51821,localPortNumber=51821
```

또는 Terraform output의 `wireguard_ui_bootstrap_command`를 사용한다.

브라우저에서 아래 주소로 접속해 첫 client를 생성한다.

```text
http://127.0.0.1:51821
```

### VPN 연결 후 UI 접근

VPN 연결 후에는 Terraform output의 `wireguard_ui_url`로 접근한다.

기본값 기준:

```text
http://10.100.100.1:51821
```

wg-easy v15에서 reverse proxy 없이 HTTP UI를 사용하기 위해 `INSECURE=true`를 설정한다. UI 트래픽은 public internet이 아니라 SSM 터널 또는 WireGuard 터널 안에서만 흐른다.

## Client Allowed IPs

기본 client Allowed IPs는 전체 트래픽이 아니라 관리에 필요한 대역만 포함한다.

- common VPC CIDR
- WireGuard VPN CIDR
- `additional_wireguard_allowed_ips`

`0.0.0.0/0` full tunnel이 필요한 경우에는 wg-easy에서 해당 client config만 별도로 수정한다.

## NAT 구성

WireGuard EC2는 `source_dest_check=false`와 OS IP forwarding/MASQUERADE 설정으로 private subnet의 NAT 인스턴스 역할도 수행한다.

`enable_private_nat_route=true`이면 `aws-common`의 private route table에 `0.0.0.0/0` route를 WireGuard EC2 network interface로 추가한다.

이미 다른 NAT instance 또는 NAT gateway로 `0.0.0.0/0` route가 존재하면 충돌할 수 있다. 이 경우 기존 route를 제거하거나 `enable_private_nat_route=false`로 설정한다.

## 로그

wg-easy 컨테이너 로그는 Docker `awslogs` driver를 통해 CloudWatch Logs로 전송한다.

로그 그룹 이름은 Terraform output의 `wg_easy_log_group_name`에서 확인한다.

서버 내부에서 직접 확인할 때는 아래 명령을 사용한다.

```bash
sudo docker logs wg-easy --tail=200
sudo tail -n 200 /var/log/cloud-init-output.log
```

## 재초기화

wg-easy의 `INIT_*` 환경변수는 컨테이너 최초 시작 시에만 적용된다. 이미 잘못된 CIDR 등으로 초기화된 경우 Docker volume을 제거하고 다시 시작해야 한다.

```bash
cd /etc/docker/containers/wg-easy
sudo docker compose down
sudo docker volume ls
sudo docker volume rm wg-easy_etc_wireguard
sudo docker compose up -d
```

이 작업은 기존 wg-easy 설정과 client config를 삭제한다. 실제 client를 생성한 뒤에는 먼저 백업 여부를 확인한다.

## 기존 Lightsail 리소스

기존 Lightsail 구성은 `backup/lightsail/` 디렉토리에 보관한다.

기존 Lightsail 리소스는 `ap-northeast-1`에 생성되어 있었다. 백업 코드는 해당 리전을 명시한다.

기존 Lightsail 리소스가 `wireguard-server` state에 남아 있는 상태에서 현재 EC2 코드로 plan을 실행하면 Terraform이 Lightsail 리소스 삭제를 계획할 수 있다.

기존 Lightsail을 삭제하려면 `ap-northeast-1` provider로 삭제되도록 별도 절차를 잡아야 한다. 유지하거나 수동으로 정리하려면 apply 전에 state 분리 또는 제거가 필요하며, state 작업은 별도 확인 후 진행한다.

![wg-ui](./wg-ui.png)
