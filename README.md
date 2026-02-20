# ProjectManager

A native macOS app to manage, run, and monitor your local web development projects — all from one place.

Built with SwiftUI for macOS 15.7+.

![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift)
![Platform](https://img.shields.io/badge/Platform-macOS-blue?logo=apple)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Auto-detection** of project types: Node.js, Deno, Bun, and plain Web (HTML/CSS/JS)
- **Run projects** directly from the app with integrated terminal output
- **Server URL detection** — automatically detects the local server URL and lets you open it in your browser
- **Git status** overview: current branch, recent commits, unpushed commits, modified and untracked files
- **Health score** for each project based on Git status and disk usage
- Open projects in **Finder**, **VS Code**, or **Cursor** with one click
- Search and filter across all your projects
- **Unsupported project alert** — clear feedback when a non-web project folder is added

## Supported Project Types

| Type | Detection | Run Command |
|------|-----------|-------------|
| Node.js | `package.json` | `npm/pnpm/yarn run dev` |
| Deno | `deno.json` / `deno.jsonc` | `deno task dev` |
| Bun | `bunfig.toml` / `bun.lockb` / `bun.lock` | `bun run dev` |
| Web | `.html` files (no framework) | `python3 -u -m http.server 8000` |

## Requirements

- macOS 15.7+
- Xcode 26.2+

## Build

Open `ProjectManager.xcodeproj` in Xcode and run, or:

```bash
xcodebuild -scheme ProjectManager build
```

## Author

**Andrés Bedoya G.**

## License

This project is licensed under the [MIT License](LICENSE). You are free to use, modify, and distribute it.
