# Contributing to LLM Workspace

Thank you for your interest in contributing! This document provides guidelines and information for contributors.

## How to Contribute

### Reporting Issues

- Check existing issues first to avoid duplicates
- Include your OS, tmux version, and shell
- Provide steps to reproduce the issue
- Include relevant error messages or screenshots

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- Use 4-space indentation in shell scripts
- Add comments for non-obvious logic
- Follow existing naming conventions
- Keep functions focused and small

## Areas for Contribution

### High Priority

- **New LLM Providers**: Add support for Gemini CLI, Copilot CLI, etc.
- **Documentation**: Improve setup guides, troubleshooting
- **Cross-platform**: Better Linux support, WSL testing

### Ideas

- Additional tmux layouts (2-pane, 4-pane options)
- Integration with other development tools
- Usage analytics and reporting
- Custom themes for tmux

## Adding a New Provider

To add support for a new LLM CLI:

1. Create a new directory: `providers/<provider-name>/`
2. Add the following files:
   - `settings.json` - Provider-specific settings (if applicable)
   - `usage-monitor.sh` - Usage tracking script (optional)
   - Any additional integration scripts
3. Update `bin/workspace` to recognize the new provider
4. Add documentation in `docs/PROVIDERS.md`
5. Update the README

### Provider Interface

At minimum, a provider needs:

```bash
# In bin/workspace, add to get_llm_command():
case "$PROVIDER" in
    your-provider)
        echo "your-cli-command"
        ;;
esac
```

For full integration, implement:
- Usage monitoring (if the provider has usage limits)
- Status hooks (if the CLI supports them)
- Configuration sync (settings files, etc.)

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/threefold-workspace.git
cd threefold-workspace

# Create a test environment
./install.sh

# Make changes and test
ws-fresh
```

## Testing

Before submitting a PR:

1. Test on macOS and/or Linux
2. Verify all tmux shortcuts work
3. Test with both zsh and bash
4. Check that the install script works from scratch

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers get started
- Celebrate contributions of all sizes

## Questions?

Open an issue with the "question" label or reach out to the maintainers.

---

Thank you for contributing!
