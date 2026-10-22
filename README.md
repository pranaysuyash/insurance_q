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

## Canonical deployment platform — Render

**Single source of truth:** [`render.yaml`](render.yaml) (Infrastructure-as-Code).

CoverWise backend runs on **Render** (Singapore region), chosen over AWS App Runner,
Google Cloud Run, and Railway. See
[`docs/planning/deployment/platform_decision_reassessment_2026-07-28.md`](docs/planning/deployment/platform_decision_reassessment_2026-07-28.md)
for the full rationale.

**Two services, deployed from one Docker image:**
- `coverwise-api` — FastAPI web service (Render `web` type, auto-deploy on push)
- `coverwise-worker` — Outbox dispatcher (Render `worker` type, always-on)

**Data layer:** Supabase Postgres + pgvector + private Supabase Storage.
All secrets are in the Render dashboard Environment tab. Never in this file.

> ⚠️ **Historical references to Cloud Run, App Runner, Azure, and Railway in older docs are
> superseded.** The `render.yaml` in the project root is the authoritative deployment spec.
> Updated: 2026-09-07. Resolves doc-drift items D1/M-15 from the debt register.

## Launch status — current as of 2026-09-07

CoverWise is **not yet deployed for customer use**. Pre-launch requirements:
- Render services provisioned and secrets configured
- Supabase migrations applied to production project
- Mobile `API_BASE_URL` dart-define pointed at live Render URL
- Hosted legal pages, custom domain, and Play Store release review

Policy analysis requires an online secure backend; local `pending_upload` state
is a transport-recovery queue (retried automatically on reconnect), not offline
analysis. See [`docs/review/launch_readiness_review_2026-07-12.md`](docs/review/launch_readiness_review_2026-07-12.md)
for the last gate review.

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
- **Backend Tests**: 828+ collected, 0 failed (as of 2026-09-07). Full suite: `./venv/bin/pytest`
- **Flutter Tests**: Run via `flutter test --dart-define-from-file=.dartdefine.env --concurrency=1`; `flutter analyze` must show 0 errors
- **AI Model**: `gpt-5-nano` (primary) with `gpt-4o-mini` fallback; embedding via `text-embedding-3-small`

### Running Tests
   ```bash
# Backend tests (from project root)
./venv/bin/pytest -v

# Flutter tests (from mobile/ directory)
cd mobile
flutter test --dart-define-from-file=.dartdefine.env --concurrency=1
```

The `.dartdefine.env` file provides `API_BASE_URL` so that `AppConfig.baseUri` does not
throw `StateError` in tests. See `mobile/.dartdefine.env` for details.

## 🚀 Deployment

### Backend Deployment — Render
```bash
# Canonical deployment is Render (Infrastructure-as-Code via render.yaml).
# Connect the repo in the Render dashboard or run: render blueprint apply
# Set all secrets in the Render dashboard Environment tab (never commit them).
# See render.yaml for service definitions (coverwise-api + coverwise-worker).
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
