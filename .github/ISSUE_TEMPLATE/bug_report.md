---
name: Bug report
about: Something renders wrong, or behaves differently from the docs
title: ""
labels: bug
assignees: ""
---

**Describe the bug**
A clear description of what's wrong, and what you expected instead.

**Device / OS**
- Device or simulator:
- OS version:
- `native_adaptive_ui` version:
- Flutter version (`flutter --version`):

**`DesignEra` in effect**
If known — check the "Design" tab of the example app, or log
`AdaptiveScope.of(context).era`.

**`NativePolicy`**
Does the issue still happen with `NativePolicy.dartOnly`? This narrows it to
either the native embedding or the Dart fallback.

**Screenshot**
If it's a visual bug, a screenshot is the single most useful thing you can
attach — most rendering bugs are invisible in code review and obvious in a
screenshot.

**Minimal reproduction**
The smallest widget tree that reproduces it, if you can isolate one.

**Additional context**
Anything else relevant.
