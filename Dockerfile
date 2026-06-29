# ── Playwright test runner ────────────────────────────────────────────────────
# Starts from Node so the Playwright version is always derived from package.json
# rather than hard-coding an image tag that may lag the package.
FROM node:20-bookworm-slim

WORKDIR /app

# Copy lockfiles first — this layer is cached until deps change
COPY package.json package-lock.json ./

RUN npm ci

# Install all browsers (Chromium, Firefox, WebKit) and their OS-level dependencies
RUN npx playwright install --with-deps

# Tests run against the live site; only config + test files are needed
COPY playwright.config.ts ./
COPY tests/ ./tests/

# Volumes for playwright-report/ and test-results/ are declared in docker-compose.yml
# so the HTML report survives after the container exits.
CMD ["npx", "playwright", "test", "--reporter=line,html"]
