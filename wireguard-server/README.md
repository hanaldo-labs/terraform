# Wireguard 서버

wg-easy v15 기반 WireGuard VPN 서버를 AWS EC2에 구성한다.

- EC2 Amazon Linux 2023 ARM64
- Docker Compose
- [wg-easy v15](https://wg-easy.github.io/wg-easy/v15.3/examples/tutorials/basic-installation/)

기존 Lightsail 구성은 `backup/lightsail/` 디렉토리에 보관한다.

기존 Lightsail 리소스는 `ap-northeast-1`에 생성되어 있었다. 백업 코드는 해당 리전을 명시한다.

## 1. 사전 조건

1. `aws-common` 프로젝트가 먼저 적용되어 있어야 한다.
2. `aws-common` remote state에 아래 output이 있어야 한다.
   - `vpc_id`
   - `public_subnet_ids`
   - `private_route_table_id`
3. `aws-common`에서 생성한 `common-key` EC2 key pair가 존재해야 한다.
4. `init_password` 값을 설정해야 한다.

## 2. 프로비저닝

```bash
terraform init
terraform apply
```

## 3. 접속

apply 후 WireGuard VPN을 연결하고 output의 `wireguard_ui_url`로 접근한다.

wg-easy v15에서 reverse proxy 없이 HTTP UI를 사용하기 위해 `INSECURE=true`를 설정한다. UI 포트는 public에 publish하지 않고 WireGuard VPN 내부에서만 접근한다.

WireGuard 서버 자체 관리는 SSH가 아니라 AWS Systems Manager Session Manager를 사용한다. EC2 security group은 SSH ingress를 열지 않는다.

초기 client config가 없을 때는 output의 `wireguard_ui_bootstrap_command`를 실행해 SSM port forwarding을 열고, 로컬 브라우저에서 `http://127.0.0.1:51821`로 접속해 첫 client를 생성한다.

기본 client Allowed IPs는 전체 트래픽(`0.0.0.0/0`)이 아니라 common VPC CIDR과 WireGuard VPN CIDR만 포함한다. VPN 연결 후 wg-easy UI는 WireGuard 서버의 VPN IP로 접근한다. 전체 터널링이 필요한 client는 wg-easy에서 해당 client config만 별도로 수정한다.

wg-easy의 `INIT_*` 환경변수는 컨테이너 최초 시작 시에만 적용된다. 이미 잘못된 CIDR로 초기화된 경우 `/etc/wireguard` Docker volume을 제거하고 컨테이너를 다시 시작해야 초기 설정이 다시 반영된다.

## 4. NAT 구성

WireGuard EC2는 `source_dest_check=false`와 OS IP forwarding/MASQUERADE 설정으로 private subnet의 NAT 인스턴스 역할도 수행한다.

`enable_private_nat_route=true`이면 `aws-common`의 private route table에 `0.0.0.0/0` route를 WireGuard EC2 network interface로 추가한다.

이미 다른 NAT instance 또는 NAT gateway로 `0.0.0.0/0` route가 존재하면 충돌할 수 있다. 이 경우 기존 route를 제거하거나 `enable_private_nat_route=false`로 설정한다.

## 5. 로그

wg-easy 컨테이너 로그는 Docker `awslogs` driver를 통해 CloudWatch Logs로 전송한다. 로그 그룹 이름은 output의 `wg_easy_log_group_name`에서 확인한다.

## 6. 기존 Lightsail 리소스

기존 Lightsail 리소스가 `wireguard-server` state에 남아 있는 상태에서 현재 EC2 코드로 plan을 실행하면 Terraform이 Lightsail 리소스 삭제를 계획할 수 있다.

기존 Lightsail을 삭제하려면 `ap-northeast-1` provider로 삭제되도록 별도 절차를 잡아야 한다. 유지하거나 수동으로 정리하려면 apply 전에 state 분리 또는 제거가 필요하며, state 작업은 별도 확인 후 진행한다.

![wg-ui](./wg-ui.png)
