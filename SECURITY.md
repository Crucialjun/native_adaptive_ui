# Security Policy

## Supported Versions

This package is pre-1.0 (see the README's Status section). Security fixes
are made against the latest published version on pub.dev; there is no
long-term support branch for older versions.

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Instead, report it privately using one of:

- [GitHub's private vulnerability reporting](https://github.com/gauravrajkagwaniya/native_adaptive_ui/security/advisories/new)
  (Security tab → "Report a vulnerability")
- Email: gauravrajkagwaniya@gmail.com

Include the affected version, the platform(s) it applies to, and steps to
reproduce. You should get an acknowledgement within a few days.

## Scope

`native_adaptive_ui` is a UI-rendering package — it does not handle network
requests, authentication, or persist user data itself. The most relevant
categories are the native platform channel surface (`lib/src/core/native_bridge.dart`
and the Swift/Kotlin plugin sources) and any code path that decodes external
input (e.g. `AdaptiveDestination.iconImage`/`iconSvgAsset` handling).
