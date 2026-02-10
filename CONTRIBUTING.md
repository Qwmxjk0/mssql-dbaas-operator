# Contributing

## Branching
- Use feature branches from `main`.
- Keep changes scoped (CRD, chart, docs, tests).

## Pull request checklist
- [ ] Update docs when behavior changes
- [ ] Add or update runtime evidence in `tests/`
- [ ] Confirm no secrets are committed
- [ ] Confirm image tags are explicit in examples
- [ ] Confirm `helm template` renders without error

## Validation
```bash
helm lint ./helm/mssql-helm
helm template mssql-src ./helm/mssql-helm -n dbaas-mssql > /tmp/mssql-helm.rendered.yaml
```
