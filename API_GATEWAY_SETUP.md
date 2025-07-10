# API Gateway Setup for DIS Platform

This document describes the migration from Kubernetes Ingress to Kong Gateway across all environments.

## Overview

The DIS Platform has been migrated from using Kubernetes Ingress to Kong Gateway solutions:

- **All Environments**: Kong Gateway
- **Local Development**: Kong Gateway (Minikube with NodePort)
- **Staging**: Kong Gateway (GKE with LoadBalancer)
- **Production**: Kong Gateway (GKE with LoadBalancer + High Availability)

Kong Gateway provides a unified API Gateway solution across all environments, ensuring consistent behavior and simplified deployment.

## Architecture Changes

### Before (Ingress)
```
Client → Ingress Controller → Services → Pods
```

### After (API Gateway)
```
Client → API Gateway → Services → Pods
```

## Local Development Setup (Kong Gateway)

### Prerequisites
- Minikube
- kubectl
- Docker
- Maven

### Quick Start

1. **Automated Setup**:
   ```bash
   ./build-and-deploy-local-apigateway.sh
   ```

2. **Manual Setup**:
   ```bash
   # Start Minikube
   minikube start
   
   # Configure Docker environment
   eval $(minikube docker-env)
   
   # Build applications and images
   # (See build script for detailed steps)
   
   # Deploy with Kong Gateway
   kubectl apply -k k8s/overlays/local
   
   # Update /etc/hosts
   echo "$(minikube ip) dis.local" | sudo tee -a /etc/hosts
   ```

### Kong Gateway Endpoints

- **API Gateway (Proxy)**: `http://dis.local:32080`
- **Kong Admin API**: `http://dis.local:32081`
- **Kong Manager**: `http://dis.local:32082`

### Service Endpoints via Kong

- Health Checks:
  - `http://dis.local:32080/api/acquisition/health`
  - `http://dis.local:32080/api/ingestion/health`
  - `http://dis.local:32080/api/processing/health`

- Data APIs:
  - `http://dis.local:32080/api/acquisition/entities`
  - `http://dis.local:32080/api/acquisition/fire-events`
  - `http://dis.local:32080/api/acquisition/aggregate`
  - `http://dis.local:32080/api/acquisition/monthly`
  - `http://dis.local:32080/api/ingestion/internal/metrics/realtime`

### Kong Configuration

Kong is configured via a declarative YAML configuration stored in a ConfigMap:

- **Services**: Define backend services (data-ingestion, data-processing, data-acquisition)
- **Routes**: Map URL paths to services
- **Plugins**: CORS, rate limiting, etc.

## Staging/Production Setup (Kong Gateway on GKE)

### Prerequisites
- GKE cluster running
- LoadBalancer service support

### Configuration Files
- `k8s/base/kong-gateway.yaml`: Base Kong Gateway configuration
- `k8s/overlays/staging/kong-gateway-patch.yaml`: Staging-specific patches
- `k8s/overlays/prod/kong-gateway-patch.yaml`: Production-specific patches

### Deployment
```bash
# Deploy to staging
kubectl apply -k k8s/overlays/staging

# Deploy to production
kubectl apply -k k8s/overlays/prod
```

### Features
- LoadBalancer with external IP
- High availability (3 replicas in production)
- CORS and rate limiting
- Prometheus metrics
- Pod disruption budgets
- Health checks and auto-scaling

### Service Endpoints

Once deployed, services are accessible via the LoadBalancer IP:
```
http://{EXTERNAL_IP}/api/{service}/{endpoint}
```

## Configuration Files

### Base Configuration
- `k8s/base/kong-gateway.yaml`: Kong Gateway deployment and service
- `k8s/base/gcp-api-gateway.yaml`: Google Cloud API Gateway resources
- `k8s/base/api-gateway-config.yaml`: Shared API configuration

### Overlays
- `k8s/overlays/local/kong-gateway-patch.yaml`: Local Kong configuration
- `k8s/overlays/prod/api-gateway-patch.yaml`: Production API Gateway configuration

## Migration from Ingress

### Files Removed/Replaced

- `k8s/base/ingress.yaml` → Removed (replaced with Kong Gateway)
- `k8s/overlays/local/ingress-patch.yaml` → Removed (replaced with Kong patch)

### Files Modified
- `k8s/base/kustomization.yaml`: Updated to include Kong Gateway
- `k8s/overlays/*/kustomization.yaml`: Updated patch references
- `.github/workflows/CD.yaml`: Added API Gateway setup steps

## Testing

### Local Testing (Minikube)
```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Test health endpoints
curl "http://$MINIKUBE_IP:32080/api/ingestion/health"
curl "http://$MINIKUBE_IP:32080/api/processing/health"
curl "http://$MINIKUBE_IP:32080/api/acquisition/health"

# Test API endpoints
curl "http://$MINIKUBE_IP:32080/api/acquisition/aggregate?startDate=2025-01-01&endDate=2025-01-02"
```

### Staging/Production Testing (GKE)
```bash
# Get LoadBalancer external IP
EXTERNAL_IP=$(kubectl get service kong-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test health endpoints
curl "http://$EXTERNAL_IP/api/ingestion/health"
curl "http://$EXTERNAL_IP/api/processing/health"
curl "http://$EXTERNAL_IP/api/acquisition/health"

# Test API endpoints
curl "http://$EXTERNAL_IP/api/acquisition/aggregate?startDate=2025-01-01&endDate=2025-01-02"

# Test with SSL (if configured)
curl "https://$EXTERNAL_IP/api/acquisition/aggregate?startDate=2025-01-01&endDate=2025-01-02"
```

## Benefits of API Gateway

### Kong Gateway (Local)
- **Rich Plugin Ecosystem**: Rate limiting, authentication, logging, etc.
- **Admin Interface**: Easy configuration and monitoring
- **Declarative Configuration**: Version-controlled setup
- **Local Development**: No external dependencies

### Google Cloud API Gateway (Production)
- **Managed Service**: No infrastructure to maintain
- **Integrated Security**: Built-in authentication and authorization
- **Monitoring**: Integrated with Google Cloud monitoring
- **Scalability**: Automatically scales with traffic
- **OpenAPI Support**: Standard API documentation

## Troubleshooting

### Kong Gateway Issues (All Environments)

1. **Kong Gateway not accessible**
   - Check if Kong pods are running: `kubectl get pods -l app=kong-gateway`
   - Verify service: `kubectl get service kong-gateway`
   - Check logs: `kubectl logs -l app=kong-gateway`

2. **Local Development (Minikube)**
   - Check Minikube IP: `minikube ip`
   - Verify NodePort service: `kubectl get service kong-gateway -o yaml`
   - Test direct access: `curl "http://$MINIKUBE_IP:32080/api/acquisition/health"`

3. **Staging/Production (GKE)**
   - Check LoadBalancer status: `kubectl get service kong-gateway`
   - Get external IP: `kubectl get service kong-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
   - Verify firewall rules allow traffic on ports 80/443

4. **Service discovery issues**
   - Verify backend services are running: `kubectl get pods`
   - Check Kong configuration: `kubectl get configmap kong-config -o yaml`
   - Test internal service connectivity: `kubectl exec -it <kong-pod> -- curl http://data-ingestion-service.default.svc.cluster.local:8080/health`

5. **Performance issues**
   - Check resource usage: `kubectl top pods -l app=kong-gateway`
   - Review Kong metrics: `curl http://<kong-admin-ip>:8001/metrics`
   - Scale replicas if needed: `kubectl scale deployment kong-gateway --replicas=5`

## Security Considerations

### Local Development
- Kong Gateway runs without authentication for development ease
- CORS is configured for local frontend development
- Rate limiting is set to development-friendly values
- Admin API is accessible for configuration changes

### Staging Environment
- CORS configured for staging frontend domains
- Moderate rate limiting applied
- Admin API access should be restricted
- Consider basic authentication for non-production access

### Production Environment
- Strict CORS policy with production domains only
- Aggressive rate limiting to prevent abuse
- Admin API access restricted to internal networks
- SSL/TLS termination at LoadBalancer level
- Pod security policies and network policies recommended
- Regular security updates and monitoring
- Consider implementing authentication plugins (OAuth2, JWT, etc.)

## Monitoring and Observability

### Kong Gateway Monitoring (All Environments)

#### Built-in Metrics
- Admin API provides metrics endpoint: `http://<kong-admin>:8001/metrics`
- Prometheus plugin enabled for detailed metrics collection
- Health checks via `/status` endpoint
- Request/response logging to stdout/stderr

#### Key Metrics to Monitor
- Request rate and latency
- Error rates (4xx, 5xx responses)
- Upstream service health
- Kong Gateway resource usage (CPU, memory)
- Plugin performance metrics

#### Environment-Specific Monitoring

**Local Development:**
- Basic logging and health checks
- Admin API accessible for debugging

**Staging/Production:**
- Prometheus metrics collection
- Integration with monitoring stack (Grafana, AlertManager)
- Log aggregation and analysis
- Automated alerting on failures
- Performance dashboards

## Next Steps

### Immediate Actions
1. **Test Staging Environment**: Deploy and validate Kong Gateway in staging
2. **Update CI/CD**: Modify GitHub Actions to use unified Kong Gateway approach
3. **SSL/TLS Configuration**: Add SSL certificates for production LoadBalancer
4. **Monitoring Setup**: Implement Prometheus metrics collection and Grafana dashboards

### Future Enhancements
1. **Authentication**: Implement API key, OAuth2, or JWT authentication plugins
2. **Advanced Rate Limiting**: Configure per-user and per-API rate limiting
3. **Service Mesh Integration**: Consider Kong Mesh for advanced traffic management
4. **API Documentation**: Auto-generate API docs using Kong's OpenAPI plugin
5. **Blue-Green Deployments**: Leverage Kong for canary and blue-green deployments

### Migration Benefits Achieved
- ✅ Unified API Gateway across all environments
- ✅ Consistent routing and plugin behavior
- ✅ Simplified CI/CD pipeline
- ✅ Cost reduction (no Google Cloud API Gateway fees)
- ✅ Enhanced flexibility and control

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Kong/Google Cloud API Gateway documentation
3. Check Kubernetes cluster logs and events