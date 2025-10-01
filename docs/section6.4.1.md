# 6.4.1 General Security Architecture

The CAP platform implements a security architecture focused on API Gateway-based authentication and containerized microservice protection. The security implementation is built around Kong API Gateway as the primary security enforcement point, with Firebase JWT authentication providing centralized identity management.

## Security Architecture Overview

The CAP platform security architecture implements a gateway-centric approach where Kong API Gateway serves as the primary security enforcement point for all external traffic. The architecture provides authentication, authorization, and basic security controls across the microservice ecosystem.

## Implemented Security Principles

1. **Gateway-Centric Security**: Kong API Gateway as single entry point for security enforcement
2. **Firebase JWT Authentication**: Centralized identity management with JWT token validation
3. **Selective Endpoint Protection**: Health and authentication endpoints remain public, data endpoints require authentication
4. **Container Security**: Basic container deployment with resource limits and health checks

## Security Architecture Layers

### Layer 1: API Gateway Security (Kong Gateway)

Kong API Gateway serves as the primary security enforcement point with the following implemented features:

#### Kong API Gateway Security
- Centralized entry point for all external HTTP/HTTPS traffic
- Custom jwt-firebase plugin for Firebase JWT authentication
- Selective authentication: public health/auth endpoints, protected data endpoints
- Path-based routing to backend microservices
- Basic CORS policy enforcement
- Environment-specific configurations (local, staging, production)

#### Firebase JWT Authentication Implementation
- Custom Lua plugin (jwt-firebase) integrated into Kong Gateway
- Dynamic Firebase public key fetching from Google's API
- JWT signature verification using RSA-SHA256
- Firebase-specific claim validation (iss, aud, exp)
- User context forwarding via headers (X-User-ID, X-User-Email, X-Consumer-ID)
- Firebase project integration: "cap-backend-user"

#### Network Security Controls
- HTTPS/TLS support via LoadBalancer service (ports 80/443)
- Basic network segmentation through Kubernetes services
- Internal service-to-service communication via cluster DNS

### Layer 2: Container and Kubernetes Security

Basic container and Kubernetes security controls are implemented:

#### Container Security
- Container image deployment from GitHub Container Registry (GHCR)
- Resource limits and requests for CPU and memory
- Health check probes (readiness and liveness)
- Rolling update deployment strategy
- Image pull secrets for private registry access

#### Kubernetes Security
- Namespace-based service isolation (default namespace)
- Service-to-service communication via cluster DNS
- StatefulSet deployments for data persistence (PostgreSQL, Kafka, Zookeeper)
- Basic secret management for Firebase service accounts and registry credentials

### Layer 3: CI/CD and Deployment Security

The platform implements basic security controls in the deployment pipeline:

#### CI/CD Security
- GitHub Actions workflow for automated deployment
- Secure credential management via GitHub Secrets:
  - GCLOUD_AUTH: GCP service account credentials
  - GHCR_TOKEN: GitHub Container Registry access
  - FIREBASE_SA_B64_CI: Firebase service account (base64 encoded)
  - STAGING_APP_URL: Application URL for security scanning
- Dynamic Kubernetes secret creation for Firebase service accounts
- Kustomize-based environment-specific deployments (local, staging, production)

#### Security Scanning
- OWASP ZAP Dynamic Application Security Testing (DAST) for staging deployments
- Automated security scanning triggered on staging releases
- Security scan reports generated and stored as artifacts
- Basic vulnerability detection and reporting

#### Deployment Security
- Rolling update deployment strategy with rollback capabilities
- Health check validation before deployment completion
- Automatic rollback on deployment failures
- Environment-specific configuration management

### Layer 4: Data and Service Security

Basic data protection and service security controls:

#### Database Security
- PostgreSQL StatefulSet deployment with persistent storage
- Basic database access via internal Kubernetes services
- Backup automation via CronJob (postgres-backup-cronjob)

#### Message Queue Security
- Apache Kafka StatefulSet deployment with Zookeeper coordination
- Internal cluster communication for message streaming
- Topic-based data flow: "dis-pdus" for PDU message streaming

#### Service Communication
- Internal service-to-service communication via Kubernetes cluster DNS
- Service discovery through Kubernetes services
- Internal-only endpoints for service communication (e.g., /internal/metrics/realtime)
- Basic network isolation through Kubernetes service boundaries

## Current Security Architecture Limitations

### Not Yet Implemented
- Advanced role-based access control (RBAC)
- Container security contexts and hardening
- Network policies and micro-segmentation
- Encryption at rest and in transit
- Advanced secrets management and rotation
- Comprehensive monitoring and alerting
- Service mesh security (mTLS)
- Advanced vulnerability management
- Application-level security controls
- Data loss prevention

### Basic Implementation Only
- TLS/SSL configuration (basic HTTPS)
- Rate limiting (plugin referenced but not fully configured)
- Secrets management (Kubernetes native only)
- Container security (resource limits only)
- Database security (basic deployment only)

## Security Architecture Components

### External Security Perimeter
```
Internet → Cloud Load Balancer → Kong API Gateway
```
- Basic DDoS protection through cloud provider
- SSL/TLS termination
- Firebase JWT authentication
- API routing to backend services

### Internal Security Zones

#### DMZ Zone (Kong Gateway)
- API gateway security controls
- External traffic processing
- Authentication and authorization
- Basic rate limiting capabilities

#### Application Zone (Microservices)
- Basic Spring Boot applications
- Internal service communication
- Health check endpoints
- Resource-limited containers

#### Data Zone (Databases and Message Queues)
- PostgreSQL StatefulSet
- Apache Kafka with Zookeeper
- Basic persistent storage
- Internal cluster communication only

#### Management Zone (Kubernetes Control Plane)
- Standard GKE cluster management
- Basic RBAC through GKE
- Kubernetes native secrets
- Standard cluster monitoring

## Security Control Integration

The current security architecture integrates basic security controls:

### Identity and Access Management (IAM)
- Firebase-based identity management
- JWT token validation at gateway level
- Basic user authentication (no authorization roles)

### Network Security
- Basic Kubernetes service networking
- Cloud provider network isolation
- Internal cluster DNS resolution

### Application Security
- Basic Spring Boot security
- Health check endpoints
- Container resource limits

### Data Protection
- Basic database deployment
- Kubernetes native secrets
- Internal service communication

This general security architecture provides a foundation for protecting the CAP platform, with significant opportunities for enhancement in advanced security controls, monitoring, and compliance capabilities.