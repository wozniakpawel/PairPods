# Contributing to PairPods

Thank you for your interest in contributing to PairPods! We're excited to have you join our community. This document provides guidelines and steps for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a welcoming, inclusive, and harassment-free environment. Be respectful to others and their contributions, regardless of their experience level, gender, identity, race, religion, or nationality.

## Development Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later (required for project format compatibility)
- Two compatible Bluetooth audio devices for testing
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for code formatting

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PairPods.git
   cd PairPods
   ```
3. Set up the upstream remote:
   ```bash
   git remote add upstream https://github.com/wozniakpawel/PairPods.git
   ```

## Development Workflow

### Branch Structure

- `main` - Production code only. Protected and only used for releases.
- `develop` - Integration branch for features and fixes. Contributors target this branch.
- Feature/fix branches - Where contributors do their work before creating PRs to `develop`.

### Creating a Feature Branch

Always create a new branch for your changes, branching from `develop` (not `main`):

```bash
# Ensure your develop branch is up-to-date
git checkout develop
git pull upstream develop

# Create a new branch for your feature or fix
git checkout -b feature/descriptive-name
# OR
git checkout -b fix/issue-description
```

### Making Changes

1. Make your code changes in your feature branch
2. Run SwiftFormat to ensure your code meets our style guidelines:
   ```bash
   swiftformat --swiftversion 6.0.3 .
   ```
3. Test your changes thoroughly
4. Commit your changes with meaningful commit messages:
   ```bash
   git add .
   git commit -m "Implement feature X"
   ```
5. Push your changes to your fork:
   ```bash
   git push origin feature/descriptive-name
   ```

### Keeping Your Branch Updated

If your branch gets behind the develop branch, update it:

```bash
git checkout develop
git pull upstream develop
git checkout feature/descriptive-name
git rebase develop
# OR
git merge develop
```

### Submitting a Pull Request

1. Ensure your code is properly formatted and passes all tests
2. Push your branch to your fork if you haven't already:
   ```bash
   git push origin feature/descriptive-name
   ```
3. Go to GitHub and create a Pull Request from your branch to the `develop` branch of the main repository (not to `main`)
4. Fill out the PR template with details about your changes
5. Wait for CI checks to complete
6. Address any review comments or CI issues

> **Important**: Regular contributors should always create PRs targeting the `develop` branch, not the `main` branch. Only the project maintainer creates PRs from `develop` to `main` when releasing new versions.

## Release Process

> **Note**: The release process is managed by the project maintainer only. Regular contributors do not need to perform these steps.

### For Project Maintainer Only

#### Release Checklist

1. Ensure the `develop` branch contains all desired changes and is stable
   ```bash
   git checkout develop
   git pull
   ```

2. Create a release branch from `develop`:
   ```bash
   git checkout -b release/x.y.z develop
   ```

3. Update version and build number in Xcode:
   - Increment "Version" (CFBundleShortVersionString)
   - Increment "Build" (CFBundleVersion)

4. Update `CHANGELOG.md`:
   - Add new version number and release date
   - List all new features, improvements, and bug fixes
   - Use the format: `## [x.y.z] - YYYY-MM-DD`

5. Commit the version and changelog updates:
   ```bash
   git add .
   git commit -m "Bump version to x.y.z"
   ```

6. Push the release branch and create a PR to `develop`:
   ```bash
   git push origin release/x.y.z
   # Create PR from release/x.y.z to develop
   ```

7. After the PR is merged to `develop`, create a PR from `develop` to `main`
   
8. After the PR to `main` is merged, create and push a tag:
   ```bash
   git checkout main
   git pull
   git tag vx.y.z
   git push origin vx.y.z
   ```

9. The GitHub Actions release workflow will automatically:
   - Build the app
   - Sign it with the developer certificate
   - Notarize the app with Apple
   - Create a GitHub release
   - Update the Sparkle appcast.xml for auto-updates

## Testing Guidelines

- Test with various Bluetooth audio devices
- Verify that the menubar app functions correctly
- Check that audio sharing works as expected
- Ensure the UI remains responsive

## License

By contributing to PairPods, you agree that your contributions will be licensed under the MIT License.

## Support

If you'd like to support the project financially:
- [GitHub Sponsors](https://github.com/sponsors/wozniakpawel)
- [Buy Me a Coffee](https://www.buymeacoffee.com/wozniakpawel)

## Contact

For additional questions or concerns, please open an issue on GitHub.

Thank you for contributing to PairPods! 🎧