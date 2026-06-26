# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
EventHub is a full-stack event ticket booking platform built for QA training. Users can browse events, book tickets, manage bookings, and create events. Each user operates in an isolated sandbox.

## Tech Stack
- **Frontend**: Next.js 14 (App Router), React 18, TypeScript, Tailwind CSS, React Query v5
- **Backend**: Express.js, Prisma ORM, MySQL 8+
- **Auth**: JWT (7-day expiry), bcryptjs — token stored in `localStorage`
- **Testing**: Playwright E2E (Chromium only, parallel disabled)

## Commands

```bash
npm run setup        # Install deps in both /backend and /frontend
npm run dev          # Start frontend (port 3000) + backend (port 3001) concurrently
npm run seed         # Insert 10 static events into the database
npm run db:push      # Push Prisma schema to DB (non-interactive)
npm run migrate      # Run prisma migrate dev (interactive, creates migration files)
npm run build        # Build Next.js frontend for production
npm run lint         # Lint frontend

npm run test                                                          # Run all Playwright tests
npm run test:ui                                                       # Playwright with UI mode
npm run test:report                                                   # Open HTML test report
npx playwright test tests/<file>.spec.js --reporter=line             # Run a single test file
```

## Environment Setup

**Backend** — `/backend/.env`:
```env
DATABASE_URL="mysql://root:your_password@localhost:3306/eventhub"
PORT=3001
NODE_ENV=development
CORS_ORIGIN=http://localhost:3000
```

**Frontend** — `/frontend/.env.local`:
```env
NEXT_PUBLIC_API_URL=http://localhost:3001/api
```

## Architecture

### Backend (layered)
```
Routes → Controllers → Services → Repositories → Prisma → MySQL
```
- **Routes** (`src/routes/`): Express routers with Swagger JSDoc annotations
- **Controllers** (`src/controllers/`): Thin HTTP layer — parse request, call service, return response
- **Services** (`src/services/`): Business logic, validation, transactions
- **Repositories** (`src/repositories/`): Pure Prisma data access, no business logic
- **Validators** (`src/validators/`): express-validator middleware chains
- **Errors** (`src/utils/errors.js`): `NotFoundError`, `InsufficientSeatsError`, `ValidationError` — mapped to HTTP codes in `middleware/errorHandler.js`
- **Swagger UI**: Available at `http://localhost:3001/api/docs`

### Frontend (Next.js App Router)
- **Pages** (`app/`): `events/`, `events/[id]/`, `bookings/`, `bookings/[id]/`, `admin/events/`, `admin/bookings/`
- **Data fetching**: React Query hooks in `lib/hooks/` call `lib/api/` Axios clients
- **UI primitives** (`components/ui/`): Button, Modal, Toast, Pagination, Badge, etc.
- **Auth**: JWT stored in `localStorage`; Axios interceptor in `lib/api/client.js` attaches it

### Database Models (Prisma)
- **User**: `id`, `email` (unique), `password`, `events[]`, `bookings[]`
- **Event**: `id`, `title`, `category`, `venue`, `city`, `eventDate`, `price`, `totalSeats`, `availableSeats`, `isStatic` (bool), `userId` (null for seeded events)
- **Booking**: `id`, `bookingRef` (unique), `eventId`, `userId`, `customerName`, `customerEmail`, `customerPhone`, `quantity`, `totalPrice`, `status`

## Key Business Rules

- **Max 6 user-created events** per account — overflow triggers FIFO deletion of the oldest event
- **Max 9 bookings** per user — overflow triggers FIFO deletion of the oldest booking
- **Booking reference format**: `[FIRST_LETTER_OF_EVENT_TITLE]-[6_ALPHANUMERIC]` (e.g., event "Tech Summit" → ref `T-A3B2C1`)
- **Per-user seat availability**: For user-created (dynamic) events, available seats = `totalSeats - sum(user's booking quantities)`. This lets one user book the same event multiple times for testing.
- **Refund eligibility** (client-side only): quantity = 1 → eligible; quantity > 1 → not eligible. Shows a 4-second spinner before revealing the result.
- **Sandbox warning banners**: Appear on Events page when user has 5+ events, and on Bookings page near the limit
- **Static events** (`isStatic: true`): Seeded, shared across all users, immutable (cannot be edited or deleted)
- **Cross-user isolation**: Accessing another user's booking returns 403 "Access Denied"
- **Price**: `totalPrice = event.price × quantity`

## Testing

### Test Accounts
| Account    | Email                    | Password    | Use for            |
|------------|--------------------------|-------------|-------------------|
| Gmail User | rahulshetty1@gmail.com   | Magiclife1! | Primary test user |
| Yahoo User | rahulshetty1@yahoo.com   | Magiclife1! | Cross-user tests  |

### Conventions
- Test files: `tests/<feature-name>.spec.js`
- Each test must be self-contained: login → action → assert
- **Locator priority**: `data-testid` > role > label/placeholder > ID > CSS class
- Never use `page.waitForTimeout()` — use `expect().toBeVisible()` instead
- Exception: testing timed UI (refund spinner) may use `not.toBeVisible({ timeout: 6000 })`
- Generate unique test data with `Date.now()` to avoid pollution across runs
- For multi-step tests, use `// -- Step N: Description --` comment blocks

### Key `data-testid` Attributes
`event-card`, `book-now-btn`, `quantity-input`, `customer-name`, `customer-email`, `customer-phone`, `confirm-booking-btn`, `booking-ref`, `booking-card`, `cancel-booking-btn`, `confirm-dialog-yes`, `admin-event-form`, `event-title-input`, `add-event-btn`, `event-table-row`, `edit-event-btn`, `delete-event-btn`, `nav-events`, `nav-bookings`

## Custom Slash Commands (Skills)
Located in `.claude/skills/`:
- `/generate-tests <feature>` — Writes and validates Playwright tests in a real browser (uses Playwright MCP)
- `/review-tests <file>` — Reviews test code quality against best practices
- `/create-scenarios <area>` — Creates test scenario documents
- `/test-strategy <scenarios>` — Assigns tests to the optimal pyramid layer

### Skill Reference Docs (`.claude/skills/eventhub-domain/`)
- `business-rules.md` — Authoritative business rules and edge cases
- `user-flows.md` — Step-by-step user flows and seeded test data
- `ui-selectors.md` — Full list of `data-testid` selectors
- `api-reference.md` — API endpoint details

Read these before writing any test code.
