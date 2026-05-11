# Environment check

This file records what was verified on the development machine and what this project expects.

## Check results (latest)

| Tool | Status | Notes |
|------|--------|-------|
| **Node.js** | Installed | `v22.12.0` at `/usr/local/bin/node` |
| **npm** | Installed | `11.2.0` at `/usr/local/bin/npm` |
| **Java (JRE/JDK)** | OK (CLI) | Temurin **17.0.18** verified via `java -version` (required for ColdFusion 2025). |
| **Adobe ColdFusion 2025** | Partial / unclear | Startup item exists at `/Library/StartupItems/ColdFusion2025`, installer found under `~/Downloads/ColdFusion_2025_*`, but no app bundle was detected under `/Applications`. |
| **CommandBox** | Not installed | Not required for this repo anymore (CF2025-only target). |
| **Lucee** | Not used | This project now targets Adobe ColdFusion 2025 only. |

## Required runtime for this repository

1. **Adobe ColdFusion 2025**
2. **Java 17+** available to the ColdFusion runtime
3. **Node.js + npm** (optional; not required for current ColdFusion-only UI)

## Re-check commands

```bash
node --version
npm --version
java -version
```

Optional (macOS):

```bash
/usr/libexec/java_home -V
```
