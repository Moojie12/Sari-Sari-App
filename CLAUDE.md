# Sari-Sari Project Guidelines for Claude

## Project Overview
This is a Flutter-based point-of-sale system called "Sari-Sari" for managing small retail stores.

## Development Guidelines
- Follow Flutter and Dart best practices
- Maintain clean, readable code with proper documentation
- Ensure proper state management
- Write tests for new features
- Keep UI consistent and user-friendly

## Firebase Integration
This project uses Firebase for:
- Authentication (Admin login)
- Cloud Firestore (Data storage)
- Cloud Functions (Backend logic)
- Firebase Hosting (Web deployment)

## Admin Features
- Dashboard with overview statistics
- Product management
- Category management
- Archive functionality
- User management (to be implemented)
- Settings management (to be implemented)

## Commit Message Format
Use descriptive commit messages. When using Claude Code, commit messages will automatically include:
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>

## Code Organization
- lib/: Main Dart code
  - admin/: Admin panel code
  - auth/: Authentication code
  - core/: Core services and utilities
  - users/: User-facing code (to be developed)
- linux/, macos/, windows/, android/, web/: Platform-specific code
- public/: Web assets
- assets/: Static assets (images, fonts, etc.)