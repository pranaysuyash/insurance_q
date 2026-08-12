# CoverWise

An insurance companion that reads your policy documents, surfaces the details that matter,
and answers grounded questions in plain language.

## Product doctrine (Proposed, awaiting sign-off)

Product decisions follow a layered doctrine stack:

- **Constitution:** [`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`](docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md) — what the product is and refuses to be.
- **Wedge & strategy:** [`docs/architecture/FIRST_PRINCIPLES_WEDGE.md`](docs/architecture/FIRST_PRINCIPLES_WEDGE.md)
- **Commercial boundary:** [`docs/architecture/FREE_VS_PAID_BOUNDARY.md`](docs/architecture/FREE_VS_PAID_BOUNDARY.md) (all prices Proposed)
- **Reconciliation ADR:** [`docs/decisions/ADR-2026-07-29-02`](docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **Quick navigation:** [`docs/planning/product/DOCTRINE_INDEX.md`](docs/planning/product/DOCTRINE_INDEX.md)

## CoverWise launch positioning

- Core promise: help people understand the insurance policy they already own.
- Primary surfaces: policy summaries, grounded Q&A, renewal readiness, and claim-time details.
- Trust rule: the policy document remains the source of truth, and the app should always defer to
  the insurer for binding decisions.
- Launch copy reference: [`docs/review/coverwise_play_store_listing.md`](docs/review/coverwise_play_store_listing.md)
- Launch assets reference: [`docs/review/coverwise_play_store_launch_assets.md`](docs/review/coverwise_play_store_launch_assets.md)

## Doctrine stack (product boundary hierarchy)

Product decisions follow a layered doctrine stack. See [the decision index](docs/decisions/README.md)
for precedence and [ADR-2026-07-29-02](docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
for the full reconciliation.

| Layer | Document | Status |
|-------|----------|--------|
| Product constitution | [`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`](docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md) | Proposed (requires sign-off) |
| Strategy & wedge | [`docs/architecture/FIRST_PRINCIPLES_WEDGE.md`](docs/architecture/FIRST_PRINCIPLES_WEDGE.md) | Proposed |
| Commercial boundary | [`docs/architecture/FREE_VS_PAID_BOUNDARY.md`](docs/architecture/FREE_VS_PAID_BOUNDARY.md) | Proposed |

---

## Current deployment source of truth

The company-era AWS deployment notes below are historical records and are not the
current launch plan. CoverWise is now being prepared as a solo product. The
canonical platform architecture is [`docs/planning/coverwise_long_term_platform_decision_2026-07-12.md`](docs/planning/coverwise_long_term_platform_decision_2026-07-12.md),
which selects one Cloud Run FastAPI service backed by Supabase Postgres,
pgvector, and private Storage. The live release command is
[`tools/deploy_cloud_run.sh`](tools/deploy_cloud_run.sh); it is not yet proof of
a deployed production service. See [`docs/archive/deployment/README.md`](docs/archive/deployment/README.md)
for preserved historical deployment material.

## Launch status — current as of 2026-07-13

CoverWise is **not yet deployed for customer use**. The current launch path is:

- Flutter mobile client with explicit policy-processing consent and no demo
  content in release builds.
- One Cloud Run API service with application-level bearer authorization.
- Supabase Postgres/pgvector and private Supabase Storage as the sole durable
  document path.
- Hosted legal pages, Secret Manager values, Supabase migrations, custom domain,
  and deployed end-to-end acceptance evidence still required before release.

Policy analysis requires an online secure backend; local pending-upload support
is only a transport-recovery state, not offline analysis. For current launch
gates, see
[`docs/review/launch_readiness_review_2026-07-12.md`](docs/review/launch_readiness_review_2026-07-12.md).

> The remainder of this README is a preserved June 2025 historical snapshot.
> It contains obsolete AWS, Azure, Qdrant, Redis, deployment, cost, and
> readiness claims. Do not follow it for the July 2026 launch.


## 🛠️ Development Setup

### Prerequisites
- Flutter SDK (latest stable)
- Python 3.11+
- Docker Desktop
- Azure CLI
- Git

### Quick Start
    ```bash
# Clone repository
git clone <repository-url>
    cd insurance_app

# Backend setup (canonical local environment)
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -r requirements-local.txt

# Frontend setup
cd mobile
flutter pub get
flutter run

# Run backend tests through uv and the project venv
cd ..
tools/run_backend_tests.sh tests/
```

### Environment Configuration
    ```bash
# Copy environment template
cp sample.env .env

# Configure required variables
OPENAI_API_KEY=your_openai_key
AZURE_SUBSCRIPTION_ID=your_subscription_id
```

## 📚 Documentation

### User Documentation
- [User Guide](docs/user_experience/user_interface/README.md)
- [Feature Overview](docs/planning/product/README.md)

### Technical Documentation
- [Architecture Overview](docs/technical/architecture/README.md)
- [API Documentation](docs/reference/api_documentation/README.md)
- [Deployment Guide](docs/technical/deployment/README.md)
- [Lessons Learned](docs/technical/implementation/lessons_learned.md)

### Deployment & Operations
- [Azure Deployment Status](docs/technical/deployment/azure_deployment_status.md)
- [Play Store Deployment Checklist](docs/technical/deployment/play_store_deployment_checklist.md)
- [Known Issues](docs/technical/implementation/known_issues.md)

## 🧪 Testing

### Test Coverage
- **Backend Tests**: 378 passed, 1 deployment-gated integration test skipped
- **API Integration**: Run through the live staging API and targeted Supabase checks
- **Flutter Tests**: 636 passed in the current full suite (`--concurrency=1`); `flutter analyze --no-fatal-infos` also passes
- **Performance**: Response times < 2 seconds

### Running Tests
   ```bash
# Backend tests
tools/run_backend_tests.sh tests/ -v

# API tests (canonical backend is Cloud Run; start via tools/deploy_cloud_run.sh).
# The legacy ./scripts/test_azure_apis.sh was removed with the Azure dead path.

# Flutter tests (mobile/ directory)
   cd mobile
flutter test --dart-define-from-file=.dartdefine.env
```

The `.dartdefine.env` file provides `API_BASE_URL` (and optional overrides) so that
`AppConfig.baseUri` does not throw `StateError` in the default production environment.
See `mobile/.dartdefine.env` for details and available overrides.


## 🚀 Deployment

### Play Store Deployment
1. **App Bundle Build Proof**: The release bundle was built successfully in the last staging run; the ignored `mobile/build/` outputs were later removed to recover disk pressure and must be regenerated before distribution.
2. **Follow Checklist**: [Play Store Deployment Guide](docs/technical/deployment/play_store_deployment_checklist.md)
3. **Upload to Play Console**: Use the App Bundle for optimal delivery

### Backend Deployment
   ```bash
# Canonical backend deployment is Cloud Run + Supabase.
# See tools/deploy_cloud_run.sh and tools/deploy_outbox_worker.sh.
# (The legacy Azure deploy scripts were removed — agent-built dead path
#  with a no-password Redis anti-pattern; see ADR-2026-08-12-01.)
```

## 🔧 Troubleshooting

### Common Issues
1. **Redis Connection**: Service works without Redis, just slower
2. **RAG Service Degraded**: Basic functionality still available
3. **Build Failures**: Ensure Flutter SDK is up to date

### Support Resources
- [Known Issues](docs/technical/implementation/known_issues.md)
- [Lessons Learned](docs/technical/implementation/lessons_learned.md)
- Azure service logs via Azure Portal

## 📈 Roadmap

### Immediate (Post-Launch)
- [ ] Fix Redis connectivity issues
- [ ] Optimize RAG service performance
- [ ] Implement Application Insights monitoring
- [ ] Enhance error handling

### Short-term (1-2 months)
- [ ] iOS App Store deployment
- [ ] Advanced document analysis features
- [ ] User authentication and profiles
- [ ] Performance optimizations

### Long-term (3-6 months)
- [ ] Multi-language support
- [ ] Enterprise features
- [ ] Advanced AI capabilities
- [ ] Multi-region deployment

## 🤝 Contributing

### Development Workflow
1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request
5. Code review and merge

### Code Standards
- Python: PEP 8 with Black formatting
- Flutter: Dart style guide
- Documentation: Markdown with clear structure
- Testing: Comprehensive test coverage

## 📄 License

License terms have not yet been published. Do not reuse, redistribute, or
transfer the project as open-source software without written owner approval.

## 📞 Support

### Contact Information
- **Technical Issues**: Create GitHub issue
- **Business Inquiries**: Contact project maintainers
- **Security Issues**: Report privately to maintainers

### Resources
- **Documentation**: [docs/](docs/)
- **API Reference**: [docs/reference/api_documentation/](docs/reference/api_documentation/)
- **Deployment Guides**: [docs/technical/deployment/](docs/technical/deployment/)

---

**🎉 Ready for Play Store Deployment!**  
The app is production-ready with core functionality working and comprehensive fallback mechanisms in place. 
