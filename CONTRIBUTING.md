# Contributing to WiFi Check

Thanks for your interest in contributing. This is a small personal project, but pull requests and issues are welcome.

## Getting started

1. Fork the repo and create a branch from `main`.
2. Open `WiFiCheck.xcodeproj` in Xcode 26+.
3. Build and run the `WiFiCheck` scheme.

For changes involving the privileged helper, install to `/Applications` first:
```bash
./Scripts/install-dev.sh
```

## What's welcome

- Bug fixes
- Compatibility fixes for new macOS releases
- Performance improvements
- UI/UX improvements that stay in the spirit of the app (simple, focused)

## What to avoid

- New dependencies (keep it dependency-free)
- Features that require new entitlements or privacy permissions without a strong justification
- Changes to the release pipeline without discussion first

## Submitting a pull request

- Keep PRs focused — one fix or feature per PR
- Include a clear description of what changed and why
- If fixing a bug, describe how to reproduce it
- Test on macOS 26+ before submitting

## Reporting issues

Open an issue on GitHub. Include:
- macOS version
- What you expected to happen
- What actually happened
- Steps to reproduce

## Code style

Follow the existing Swift style in the project. No third-party formatters or linters are required.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
