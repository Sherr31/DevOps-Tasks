# DevOps-Tasks

Hands-on DevOps projects focused on AWS infrastructure, networking, and secure production patterns.

---

## Projects

| Project | Description |
|---------|-------------|
| [aws-secure-vpc](./aws-secure-vpc/) | Multi-AZ VPC with public ALB, private Auto Scaling app instances, bastion jump host, NAT Gateway, and locked-down security groups |

---

## Repository layout

```text
DevOps-Tasks/
├── README.md                 # This file
├── .gitignore                # PEM keys, pics/, local secrets
└── aws-secure-vpc/           # Terraform multi-AZ secure VPC stack
    ├── network.tf            # VPC, subnets, IGW, NAT, routes
    ├── security.tf           # ALB / Bastion / App security groups
    ├── compute.tf            # Launch template, ASG, bastion
    ├── alb.tf                # ALB, listener, target group
    ├── variables.tf / outputs.tf / versions.tf
    └── README.md             # Full architecture, deploy steps, screenshots
```

---

## Quick start

Each project is self-contained. For the secure VPC stack:

```bash
cd aws-secure-vpc
cp terraform.tfvars.example terraform.tfvars
# Set key_name to your EC2 key pair name

terraform init
terraform plan
terraform apply
```

See [aws-secure-vpc/README.md](./aws-secure-vpc/README.md) for architecture diagrams, console walkthrough, ALB testing, and bastion SSH.

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform `>= 1.5`
- An EC2 key pair in the target region (private `.pem` kept out of git)

---

## Security

- Never commit `*.pem` private keys or `terraform.tfvars`
- Prefer locking bastion SSH to your IP (`YOUR.IP/32`) instead of `0.0.0.0/0`
- Destroy labs when finished — NAT Gateway and ALB incur ongoing cost:

```bash
cd aws-secure-vpc && terraform destroy
```
