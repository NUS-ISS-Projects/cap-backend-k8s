# DIS Platform - Kubernetes Deployment with API Gateway

This repository contains the Kubernetes deployment configurations for the DIS (Distributed Interactive Simulation) Data Platform, featuring API Gateway integration for both local development and production environments.

## 🚀 Quick Start

### Local Development (Minikube + Kong Gateway)
```bash
# Automated setup
./build-and-deploy-local-apigateway.sh

# Access services via API Gateway
curl http://dis.local:32080/api/acquisition/health
```

### Production (GKE + Google Cloud API Gateway)
```bash
# Deploy via GitHub Actions (tag with *-release or *-staging)
git tag v1.0-release
git push origin v1.0-release
```

## 📋 Architecture Overview

The platform uses a unified API Gateway solution across all environments:

- **All Environments**: Kong Gateway (running in Minikube for local, LoadBalancer for GKE)
- **Configuration**: Environment-specific overlays for local, staging, and production

### Services
- **Data Ingestion Service**: Receives UDP DIS PDUs, publishes to Kafka
- **Data Processing Service**: Consumes from Kafka, processes and stores data
- **Data Acquisition Service**: Provides REST APIs for historical and real-time data
- **Supporting Services**: PostgreSQL, Apache Kafka, Zookeeper

## 🛠️ Setup Instructions

### Prerequisites
- Docker
- kubectl
- Minikube (for local development)
- Maven (for building Java applications)

### Local Development Setup

1. **Clone and build**:
   ```bash
   git clone <repository-url>
   cd cap-backend-k8s
   ./build-and-deploy-local-apigateway.sh
   ```

2. **Access services**:
   - API Gateway: `http://dis.local:32080`
   - Kong Admin: `http://dis.local:32081`
   - Kong Manager: `http://dis.local:32082`

### Production Deployment

Production deployment is automated via GitHub Actions:

1. **Staging**: Create tag with `*-staging` suffix
2. **Production**: Create tag with `*-release` suffix

The workflow will:
- Enable required Google Cloud APIs
- Install Config Connector
- Deploy API Gateway resources
- Deploy application services
- Run DAST security scans (staging only)

## 📁 Project Structure

```
k8s/
├── base/                          # Base Kubernetes resources
│   ├── kong-gateway.yaml         # Kong Gateway for local dev
│   ├── gcp-api-gateway.yaml      # Google Cloud API Gateway
│   ├── *-service*.yaml           # Application services
│   └── kustomization.yaml        # Base kustomization
├── overlays/
│   ├── local/                     # Local development overlay
│   │   ├── kong-gateway-patch.yaml
│   │   └── kustomization.yaml
│   └── prod/                      # Production overlay
│       ├── api-gateway-patch.yaml
│       └── kustomization.yaml
└── ...

scripts/
├── build-and-deploy-local-apigateway.sh  # Local setup script
├── demo-apigateway.sh                    # Demo script
└── ...
```

## 🔌 API Endpoints

### Health Checks
- `GET /api/acquisition/health` - Data Acquisition service health
- `GET /api/ingestion/health` - Data Ingestion service health
- `GET /api/processing/health` - Data Processing service health

### Data APIs
- `GET /api/acquisition/entities` - Entity state records
- `GET /api/acquisition/fire-events` - Fire event records
- `GET /api/acquisition/aggregate` - Aggregated data
- `GET /api/acquisition/monthly` - Monthly statistics
- `GET /api/ingestion/internal/metrics/realtime` - Real-time metrics

## 🧪 Testing

### Run Demo Script
```bash
./demo-apigateway.sh
```

### Manual Testing
```bash
# Local
curl http://dis.local:32080/api/acquisition/health

# Production (replace with actual URL)
curl https://your-api-gateway-url/api/acquisition/health
```

## 📚 Documentation

- [API Gateway Setup Guide](./API_GATEWAY_SETUP.md) - Comprehensive setup and configuration guide
- [Local Development Guide](./LOCAL_DEVELOPMENT.md) - Local development instructions
- [Architecture Diagrams](./pumls_mermaids/) - PlantUML architecture diagrams

## 🔧 Configuration

### Kong Gateway (Local)
Configured via `kong-config` ConfigMap with:
- Service definitions
- Route mappings
- CORS and rate limiting plugins

### Google Cloud API Gateway (Production)
Configured via:
- OpenAPI specification
- Config Connector resources
- IAM and security policies

## 🚨 Troubleshooting

### Common Issues

1. **Kong Gateway not accessible**:
   ```bash
   kubectl get pods -l app=kong-gateway
   kubectl logs -l app=kong-gateway
   ```

2. **Services not responding**:
   ```bash
   kubectl get services
   kubectl get endpoints
   ```

3. **DNS resolution issues**:
   ```bash
   # Check /etc/hosts entry
   grep dis.local /etc/hosts
   ```

See [API Gateway Setup Guide](./API_GATEWAY_SETUP.md) for detailed troubleshooting.

## 🔐 Security Features

- **Rate Limiting**: Configurable request limits
- **CORS**: Cross-origin resource sharing support
- **HTTPS**: Enforced in production
- **Authentication**: Ready for API key/OAuth integration

## 📊 Monitoring

### Local (Kong)
- Kong Admin API: `http://dis.local:32081`
- Kong Manager UI: `http://dis.local:32082`
- Metrics endpoint: `http://dis.local:32081/metrics`

### Production (Google Cloud)
- Google Cloud Monitoring
- Cloud Logging
- API Gateway metrics dashboard

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Test locally with `./build-and-deploy-local-apigateway.sh`
5. Submit a pull request

## 📄 License

[Add your license information here]

## 🆘 Support

For issues and questions:
1. Check the [troubleshooting guide](./API_GATEWAY_SETUP.md#troubleshooting)
2. Review existing GitHub issues
3. Create a new issue with detailed information