# terraform-test

Sandbox Terraform stack (S3 + Fargate ECS + Secrets Manager) in `ap-southeast-1`, account `029006056735`.
State is remote (S3 backend with native locking) so it can run from CI, not just a laptop.

## CI/CD (GitHub Actions)

`.github/workflows/terraform.yml` runs:

- **Plan** on every PR into `main` — posts the plan as a PR comment
- **Apply** on push to `main` — gated behind a required manual approval

Two one-time setup steps are needed before the pipeline will actually run.

### 1. AWS side: OIDC provider + IAM role — ✅ done

- OIDC provider for `token.actions.githubusercontent.com` — registered by an IAM
  admin (required `iam:CreateOpenIDConnectProvider`, which `iqshan` doesn't have).
- Role `terraform-test-github-actions` (trusts only `repo:iqshan-mav/terraform-test:*`)
  and its permissions policy — created by `iqshan` directly, since `iam:CreateRole`
  / `AttachRolePolicy` / `PutRolePolicy` were already granted.

Commands used, kept here for reference / reproducing in another account:

```bash
# 1a. Register GitHub as an OIDC identity provider (skip if one already exists for
#     token.actions.githubusercontent.com in this account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 1b. Create the role GitHub Actions will assume, trusting only this repo
cat > /tmp/terraform-test-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::029006056735:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:iqshan-mav/terraform-test:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name terraform-test-github-actions \
  --assume-role-policy-document file:///tmp/terraform-test-trust-policy.json

# 1c. Attach the same permissions the iqshan user already has for this stack
#     (see the iqshan user's inline policy in the AWS console for the exact
#     document — it was copied as-is into a role policy named below).
aws iam put-role-policy \
  --role-name terraform-test-github-actions \
  --policy-name terraform-test-permissions \
  --policy-document file:///tmp/terraform-test-role-permissions.json
```

### 2. GitHub side

- **Settings → Secrets and variables → Actions → Variables**: add `AWS_ROLE_ARN` =
  `arn:aws:iam::029006056735:role/terraform-test-github-actions`
- **Settings → Environments**: create an environment named `aws-test`, add yourself
  (or whoever should approve) as a **required reviewer**. This is what makes `apply`
  wait for manual sign-off instead of auto-applying on every merge to `main`.

Once both are done, opening a PR that touches any `*.tf` file will trigger a plan
comment, and merging it will wait for approval before applying.
