# GitHub Actions Workflows

## Build NixOS System

The `build-nixos.yml` workflow automatically builds the NixOS system configuration to verify it compiles correctly.

### What it does

1. **Installs Nix** - Sets up the Nix package manager in the GitHub Actions runner
2. **Builds System Derivation** - Compiles the NixOS configuration without installing it
3. **Verifies Syntax** - Checks all `.nix` files for syntax errors
4. **Reports Metrics** - Shows system closure size and dependency count

### When it runs

- On push to `main` or `copilot/create-nix-module-documentation` branches
- On pull requests to `main`
- Manually via workflow dispatch

### Configuration

The workflow uses:
- **nixos-24.05** channel for reproducible builds
- **Cachix** for optional build caching (requires `CACHIX_AUTH_TOKEN` secret)

### Viewing Results

Build results appear in:
- GitHub Actions tab for detailed logs
- Pull request checks for quick status
- Job summary with system information (derivation path, dependencies, size)

### Local Testing

To test the build locally before pushing:

```bash
# Install Nix if not already installed
curl -L https://nixos.org/nix/install | sh

# Build the system
nix-build '<nixpkgs/nixos>' -A system -I nixos-config=./configuration.nix

# Check the result
ls -lh result/
```

### Troubleshooting

**Build fails with "attribute missing":**
- Check that all module imports in `configuration.nix` are valid
- Verify module file paths exist

**Syntax errors:**
- Run `nix-instantiate --parse <file>.nix` locally to check syntax
- Ensure all Nix expressions are properly closed (braces, brackets)

**Out of memory:**
- The build may require significant RAM for large closures
- Consider using Cachix to cache expensive builds
