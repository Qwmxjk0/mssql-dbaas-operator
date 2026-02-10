# Release Process

1. Update `CHANGELOG.md` with release notes.
2. Verify docs and examples use current image tags.
3. Run manual E2E checklist (`manual-e2e-lab.md`) and attach artifacts.
4. Tag release:
```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```
