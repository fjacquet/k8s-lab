# GitHub Pages and GitHub Actions Best Practices

## GitHub Pages Configuration

### Publishing Source

GitHub Pages supports two publishing methods:

1. **Deploy from a branch** - Simple, automatic deployment from a specific branch
2. **GitHub Actions** - Custom build process with full control (recommended for Jekyll, static site generators)

### Using GitHub Actions (Recommended)

**Benefits**:
- Full control over build process
- Support for any static site generator
- Custom build steps and optimizations
- Better security with OIDC tokens

**Configuration**:
1. Go to repository Settings → Pages
2. Under "Build and deployment" → "Source", select "GitHub Actions"
3. GitHub will suggest workflow templates or use custom workflow

### Latest Action Versions (2025)

Always use the latest stable versions:

- `actions/checkout@v5` - Check out repository code
- `actions/configure-pages@v5` - Configure GitHub Pages
- `actions/upload-pages-artifact@v4` - Upload site artifact
- `actions/deploy-pages@v4` - Deploy to GitHub Pages
- `actions/jekyll-build-pages@v1` - Build Jekyll sites

## GitHub Actions Workflow Best Practices

### Workflow Structure

**Separate Build and Deploy Jobs** (Recommended):

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5
      
      - name: Setup Pages
        uses: actions/configure-pages@v5
      
      - name: Build with Jekyll
        uses: actions/jekyll-build-pages@v1
        with:
          source: ./docs
          destination: ./_site
      
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v4

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

### Required Permissions

GitHub Pages deployment requires specific permissions:

```yaml
permissions:
  contents: read      # Read repository contents
  pages: write        # Deploy to Pages
  id-token: write     # Verify deployment via OIDC
```

### Concurrency Control

Prevent multiple simultaneous deployments:

```yaml
concurrency:
  group: "pages"
  cancel-in-progress: false  # Don't cancel in-progress deployments
```

### Triggers

Recommended trigger configuration:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'docs/**'
      - 'README.md'
      - '.github/workflows/pages.yml'
  workflow_dispatch:  # Allow manual triggering
```

## Jekyll Configuration

### _config.yml Best Practices

```yaml
title: Your Project Name
description: Brief description
theme: jekyll-theme-cayman  # Or other supported theme

# GitHub integration
github:
  repository_url: https://github.com/username/repo
  is_project_page: true

# Plugins (GitHub Pages supported)
plugins:
  - jekyll-relative-links
  - jekyll-optional-front-matter
  - jekyll-titles-from-headings
  - jekyll-seo-tag

# Relative links support
relative_links:
  enabled: true
  collections: true

# Markdown settings
markdown: kramdown
kramdown:
  input: GFM
  hard_wrap: false
  syntax_highlighter: rouge

# Exclude files
exclude:
  - README.md
  - Gemfile
  - Gemfile.lock
  - node_modules
  - vendor
```

### Supported Jekyll Plugins

GitHub Pages supports these plugins by default:
- jekyll-coffeescript
- jekyll-default-layout
- jekyll-gist
- jekyll-github-metadata
- jekyll-optional-front-matter
- jekyll-paginate
- jekyll-readme-index
- jekyll-titles-from-headings
- jekyll-relative-links
- jekyll-seo-tag
- jekyll-sitemap
- jekyll-feed

## Documentation Structure

### Recommended Layout

```
docs/
├── _config.yml           # Jekyll configuration
├── index.md              # Home page
├── QUICKSTART.md         # Getting started
├── ARCHITECTURE.md       # System design
├── CONFIGURATION.md      # Configuration guide
├── VERIFICATION.md       # Verification procedures
├── SERVICE-ACCESS.md     # Service access guide
├── TESTING.md            # Testing guide
├── MAINTENANCE.md        # Maintenance operations
└── TROUBLESHOOTING.md    # Troubleshooting guide
```

### Front Matter

Add front matter to control page rendering:

```yaml
---
layout: default
title: Page Title
description: Page description for SEO
---
```

## Environment Configuration

### GitHub Pages Environment

The deployment automatically creates a `github-pages` environment:

```yaml
deploy:
  environment:
    name: github-pages
    url: ${{ steps.deployment.outputs.page_url }}
```

**Environment Protection Rules** (Optional):
- Required reviewers for deployments
- Wait timer before deployment
- Deployment branches (restrict to main/production)

## Security Best Practices

### OIDC Token Authentication

GitHub Pages uses OIDC tokens for secure deployment:

- `pages:write` - Permission to create Pages deployments
- `id-token:write` - Permission to request OIDC JWT token

The OIDC token:
- Is unique to each workflow job
- Validates workflow properties against branch protection
- Ensures deployments respect security settings

### Branch Protection

Recommended branch protection for main branch:
- Require pull request reviews
- Require status checks to pass
- Require branches to be up to date
- Include administrators

## Troubleshooting

### Common Issues

**Build Fails**:
- Check Jekyll syntax in _config.yml
- Verify all markdown files are valid
- Check for unsupported plugins
- Review workflow logs in Actions tab

**Deployment Fails**:
- Verify permissions are set correctly
- Check artifact size (must be under 10GB)
- Ensure no symbolic or hard links in artifact
- Verify environment is configured

**404 Errors**:
- Check that index.md or index.html exists
- Verify relative links are correct
- Check _config.yml exclude settings
- Wait a few minutes for DNS propagation

### Viewing Workflow Logs

1. Go to repository → Actions tab
2. Click on the workflow run
3. Click on job name to see detailed logs
4. Check each step for errors

## Performance Optimization

### Caching

Cache dependencies for faster builds:

```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: vendor/bundle
    key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
    restore-keys: |
      ${{ runner.os }}-gems-
```

### Artifact Size

Keep artifact size small:
- Exclude unnecessary files in _config.yml
- Optimize images before committing
- Remove build artifacts from repository
- Use .gitignore for generated files

## Custom Domains

### Setting Up Custom Domain

1. Add CNAME file to docs/ directory:
```
docs.example.com
```

2. Configure DNS:
```
CNAME record: docs → username.github.io
```

3. Enable HTTPS in repository settings

### Apex Domain

For apex domain (example.com):
```
A records:
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

## Monitoring and Maintenance

### Regular Checks

- Monitor workflow runs for failures
- Check Pages deployment status
- Review security alerts
- Update action versions quarterly

### Version Updates

Update actions regularly:

```bash
# Check for updates
gh api repos/actions/checkout/releases/latest

# Update in workflow file
uses: actions/checkout@v5  # Update version
```

## References

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [actions/deploy-pages](https://github.com/actions/deploy-pages)
- [actions/configure-pages](https://github.com/actions/configure-pages)
- [actions/upload-pages-artifact](https://github.com/actions/upload-pages-artifact)

## Version History

- **2025-01-14**: Updated with latest action versions (v5, v4)
- **2025-01-14**: Added OIDC security information
- **2025-01-14**: Updated Jekyll configuration best practices
