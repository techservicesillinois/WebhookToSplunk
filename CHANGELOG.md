# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

- deployment script for Linux/Mac
- optional host verification
- optional URL secret expiration with backup URL for failover scenarios
- optional administrative contact for secret expiration alert emails

## [0.1.0](Public preview release)

### Added

- Interactive deployment script for Windows
- Deployment instructions to README.md
- bicep configuration file for automatic Azure resource deployment
- secret verification in function app code

### Changed

- environment variables now configured with local.settings.json

### Removed

- removed .env configuration
- reference deploy instructions for Linux/Mac

## [0.0.1]

### Added

- function app code

### Changed

- Updated README with sample data and endpoint disclosures.

### Removed
