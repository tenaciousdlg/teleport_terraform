# HTTPBin Application Module

Creates a containerized HTTPBin testing application with Teleport application access for demonstrating web application access and HTTP testing capabilities.

## Overview

- **Use Case:** HTTP testing and application access demonstration
- **Teleport Features:** App access, web application proxy, session recording
- **Infrastructure:** EC2 instance with Docker, HTTPBin container, and Teleport agent

## Usage

```hcl
module "httpbin_app" {
  source = "../../modules/app_httpbin"
  
  env              = "dev"
  user             = "engineer@company.com"
  proxy_address    = "teleport.company.com"
  teleport_version = "17.5.2"
  
  ami_id             = data.aws_ami.linux.id
  instance_type      = "t3.micro"
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
}
```

## What It Creates

### AWS Resources
- **EC2 Instance:** Amazon Linux 2023 with Docker
- **HTTPBin Container:** kennethreitz/httpbin container on port 80

### Teleport Resources
- **Provision Token:** For application service registration

### Teleport Services Enabled
- ** Application Service:** HTTPBin web application access
- ** SSH Service:** Server management and troubleshooting access (disabled by default)

## Label Structure & Access Control

This module applies consistent labels for RBAC and dynamic discovery:

```yaml
Labels Applied:
  tier: "dev"                      # From var.env - environment-based access
  team: "engineering"              # From var.team - team-based access
  "teleport.dev/app": "httpbin"    # Application discovery label
```

### RBAC Integration
```yaml
# Example Teleport role using these labels:
allow:
  app_labels:
    tier: ["dev", "staging"]       # Access dev and staging apps
    team: ["engineering"]          # Only engineering team
    "teleport.dev/app": ["httpbin", "grafana"]  # Specific applications
```

### Customization
To adapt for your environment, modify the labels in your configuration:
```hcl
# Custom labels for your organization
labels = {
  tier               = "production"   # or "dev", "staging", "qa"
  team               = "platform"     # or "frontend", "backend", "data"
  "teleport.dev/app" = "httpbin"      # Keep for service discovery
  purpose            = "testing"      # Add purpose classification
  public_facing      = "false"        # Add exposure classification
}
```
Adjust your affiliated Roles to match as needed.

## Demo Commands

### Application Access
```bash
# List applications
tsh apps ls --labels=tier=dev

# Login to HTTPBin application
tsh apps login httpbin-dev

# Get application URL and open in browser
tsh apps config httpbin-dev

# Access HTTPBin endpoints through Teleport
curl $(tsh apps config httpbin-dev)/get
curl $(tsh apps config httpbin-dev)/headers
curl -X POST $(tsh apps config httpbin-dev)/post -d '{"test": "data"}'
```

### HTTP Testing Examples
```bash
# After logging into the application
APP_URL=$(tsh apps config httpbin-dev)

# GET requests
curl $APP_URL/get
curl $APP_URL/ip
curl $APP_URL/user-agent

# POST requests  
curl -X POST $APP_URL/post -H "Content-Type: application/json" -d '{"key": "value"}'

# HTTP methods testing
curl -X PUT $APP_URL/put -d "test data"
curl -X DELETE $APP_URL/delete
curl -X PATCH $APP_URL/patch

# Headers and cookies
curl $APP_URL/headers
curl $APP_URL/cookies/set/test/value
curl $APP_URL/cookies

# Status codes
curl $APP_URL/status/200
curl $APP_URL/status/404
curl $APP_URL/status/500
```

## Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `env` | Environment name | `string` | - |
| `user` | Creator tag | `string` | - |
| `proxy_address` | Teleport proxy address | `string` | - |
| `teleport_version` | Teleport version to install | `string` | - |
| `ami_id` | AMI ID for instance | `string` | - |
| `instance_type` | EC2 instance type | `string` | - |
| `subnet_id` | Subnet for instance | `string` | - |
| `security_group_ids` | Security group IDs | `list(string)` | - |
| `team` | Team label | `string` | `"engineering"` |

## Outputs

| Output | Description |
|--------|-------------|
| `httpbin_private_ip` | Private IP address of HTTPBin instance |

## HTTPBin Endpoints

HTTPBin provides numerous testing endpoints:

### HTTP Methods
- `GET /get` - Returns GET data
- `POST /post` - Returns POST data
- `PUT /put` - Returns PUT data
- `DELETE /delete` - Returns DELETE data
- `PATCH /patch` - Returns PATCH data

### HTTP Status Codes
- `GET /status/{codes}` - Returns given HTTP Status code
- `GET /status/200` - Returns status 200
- `GET /status/404` - Returns status 404
- `GET /status/500` - Returns status 500

### Request Inspection
- `GET /headers` - Returns headers sent by client
- `GET /ip` - Returns client IP address
- `GET /user-agent` - Returns client user agent
- `GET /cookies` - Returns cookie data

### Response Formatting
- `GET /json` - Returns JSON data
- `GET /xml` - Returns XML data
- `GET /html` - Returns HTML page
- `GET /uuid` - Returns UUID4

## Integration

This module is designed to work with the `registration` module:

```hcl
module "httpbin_registration" {
  source        = "../../modules/registration"
  resource_type = "app"
  name          = "httpbin-${var.env}"
  uri           = "http://localhost:80"
  public_addr   = "httpbin-${var.env}.${var.proxy_address}"
  labels = {
    tier               = var.env
    team               = var.team
    "teleport.dev/app" = "httpbin"
  }
  rewrite_headers = [
    "Host: httpbin-${var.env}.${var.proxy_address}",
    "Origin: https://httpbin-${var.env}.${var.proxy_address}"
  ]
  insecure_skip_verify = true
}
```

## Use Cases

### API Testing
```bash
# Test REST API endpoints
curl $(tsh apps config httpbin-dev)/anything/users/123
curl -X POST $(tsh apps config httpbin-dev)/anything/api/v1/login \
     -H "Content-Type: application/json" \
     -d '{"username": "test", "password": "secret"}'
```

### Header Analysis
```bash
# Check what headers Teleport adds
curl $(tsh apps config httpbin-dev)/headers

# Test custom headers
curl -H "X-Custom-Header: test" $(tsh apps config httpbin-dev)/headers
```

### Load Testing Preparation
```bash
# Use HTTPBin to validate load testing tools
curl $(tsh apps config httpbin-dev)/delay/2    # 2-second delay
curl $(tsh apps config httpbin-dev)/bytes/1024 # Return 1024 bytes
```

## Features

- **Complete HTTP Testing:** All standard HTTP methods and status codes
- **Request Inspection:** View headers, cookies, and request data
- **Session Recording:** All HTTP interactions recorded via Teleport
- **Lightweight:** Minimal resource usage with t3.micro instance
- **Container-based:** Easy to manage and update via Docker
- **Dynamic Discovery:** Automatically registered via labels

## Troubleshooting

### Application Service Status
This instance runs only application service for focused web app demos:

```bash
# Check application registration
tsh apps ls --labels=tier=dev
tctl apps ls

# Test application login
tsh apps login httpbin-dev --debug

# Check container status (requires SSH access to be enabled)
# Note: SSH service is disabled by default for this module
docker ps
docker logs httpbin

# Test internal application access
curl http://localhost:80/get
```

### Common Issues
- **Application Not Listed:** Check agent registration and token validity
- **Access Denied:** Verify user roles and application labels
- **Connection Timeout:** Check container status and port configuration
- **Header Issues:** Verify header rewriting in registration module

### Debug Commands
```bash
# Check application registration
tctl apps ls
tsh apps ls --debug

# Test application connectivity
tsh apps login httpbin-dev
curl $(tsh apps config httpbin-dev)/get

# Check Teleport agent logs
tctl get app/httpbin-dev
tctl status

# Container debugging (if SSH enabled)
docker exec -it httpbin /bin/sh
```

### Network Connectivity
```bash
# Test from another instance
curl http://{httpbin-private-ip}/get

# Test DNS resolution
nslookup httpbin-dev.{proxy_address}

# Check security group rules
aws ec2 describe-security-groups --group-ids {security-group-id}
```

## Security Considerations

- **No Authentication:** HTTPBin itself has no authentication (by design)
- **Internal Access:** Only accessible through Teleport proxy
- **Session Recording:** All interactions logged for audit
- **Network Isolation:** Runs in private subnet, accessed via Teleport
- **Container Security:** Uses official HTTPBin container image

## Performance

- **Lightweight:** Minimal CPU and memory usage
- **Fast Response:** Sub-100ms response times for most endpoints
- **Concurrent Users:** Can handle multiple simultaneous connections
- **Resource Usage:** Typically <100MB RAM, <5% CPU on t3.micro

## Advanced Usage

### Custom Testing Scenarios
```bash
# Simulate slow connections
curl $(tsh apps config httpbin-dev)/delay/5

# Test different content types
curl $(tsh apps config httpbin-dev)/json
curl $(tsh apps config httpbin-dev)/xml
curl $(tsh apps config httpbin-dev)/html

# Test error conditions
curl $(tsh apps config httpbin-dev)/status/429  # Rate limiting
curl $(tsh apps config httpbin-dev)/status/503  # Service unavailable

# Review Teleport SAML assertion
curl $(tsh apps config httpbin-dev)/get | jq '.[].headers'
```


### Integration Testing
```bash
# Use in CI/CD pipelines for application testing
# HTTPBin can validate that your application proxy is working correctly
curl -f $(tsh apps config httpbin-dev)/get || exit 1
```