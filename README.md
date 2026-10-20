# Dodate

Turn due dates into do dates. Tell Dodate what homework is due and how long it'll take, and it splits the work into small pieces across the days before, never planning more than your daily limit.

## Run it

```sh
npm install
npm run dev      # http://localhost:5173
npm run build    # production build in dist/
npm run lint
```

## What's inside

- **Day**: today's pieces with an animated progress ring, a date strip with per-day load dots, swipe left/right to change day, and confetti when the day is done.
- **Week**: a load chart against your daily limit, plus every piece and deadline in the week.
- **Deadlines**: what's next, progress rings per assignment, and what's been handed in.
- **Add homework**: pick a due date and length, with a live preview of how it'll be split, and a warning if it won't fit.
- Sheets you can drag down to dismiss, Undo on every change, light/dark themes (follows the system by default), and the Dodo mascot, whose idle animation matches its mood.

Data is stored in `localStorage` and rolls forward each day. Animations respect `prefers-reduced-motion`.

## Code map

- `src/lib/plan.ts`: the planner (splits work across days under a daily limit) and date helpers
- `src/lib/store.tsx`: app state, persistence, toasts with undo
- `src/lib/model.ts`: derived plan plus shared actions
- `src/screens/`: Day, Week, Deadlines, Detail
- `src/sheets/`: Add, Item, Settings sheets and the "won't fit" dialog
- `src/components/`: Dodo mascot, icons, animated primitives (ring, check, chips, sheet, toast, confetti)

Built with Vite, React, TypeScript and Framer Motion.
