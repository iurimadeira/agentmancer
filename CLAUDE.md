# Agentmancer

## UI Guidelines

### Theme

Agentmancer uses a single dark theme called "Technomancer" — cyberpunk meets digital necromancy, inspired by William Gibson's Neuromancer. There is no light mode.

The theme is defined in `assets/css/app.css` using daisyUI's theme plugin with oklch colors. The `data-theme="technomancer"` attribute is set on the `<html>` element in `root.html.heex`.

### Color Palette

| Role | Color | Usage |
|------|-------|-------|
| Primary | Toxic green (`oklch(87% 0.34 142)` / `#39ff14`) | Main actions, active states, brand |
| Secondary | Electric purple (`oklch(53% 0.32 310)` / `#bf00ff`) | Accents, gradients, secondary glow |
| Accent | Spectral cyan (`oklch(89% 0.18 192)` / `#00fff7`) | Info states, highlights |
| Base-100 | Dark purple-black (`oklch(22% 0.02 300)`) | Main background |
| Base-200 | Darker purple-black (`oklch(18% 0.025 300)`) | Sidebar, card backgrounds |
| Base-300 | Deepest purple-black (`oklch(14% 0.03 300)`) | Borders, code blocks |
| Success | Same as primary (toxic green) | Successful states |
| Warning | Sickly amber (`oklch(75% 0.17 85)`) | Running/pending states |
| Error | Blood crimson (`oklch(55% 0.25 25)`) | Failures, destructive actions |

### Typography

- **Headings, data, labels, badges, code**: JetBrains Mono (monospace)
- **Body text**: Inter (sans-serif)
- Labels are uppercase with letter-spacing
- Stat titles are uppercase, 0.7rem, with 0.1em tracking

Fonts are loaded via Google Fonts CDN (`@import` in `app.css`, preconnect in `root.html.heex`).

### Component Sizing

Use **default (normal) sizes** for buttons, inputs, selects, and checkboxes. Do not use `-sm` or `-xs` size modifiers on interactive elements. Exceptions:
- `menu-sm` is used on sidebar nav for compact layout
- `badge-sm` is acceptable for inline status indicators
- `toggle-sm` is acceptable for compact toggle switches

### Visual Effects

The theme includes several CSS-only atmospheric effects defined in `app.css`:

- **Hex grid background**: Subtle SVG pattern on `body` at 3% opacity
- **CRT scanlines**: `body::after` overlay at 3% opacity, `z-index: 9999`
- **Glow classes**: `.tm-glow-green`, `.tm-glow-purple`, `.tm-glow-cyan` for text-shadow
- **Card glow**: Cards have green-tinted borders that intensify on hover, purple glow on focus-within
- **Button glow**: Primary buttons have green box-shadow
- **Input glow**: Inputs get green border glow on focus
- **Pulse animation**: Warning badges pulse with a green/purple glow
- **Custom scrollbar**: Thin green thumb on dark track (6px width)
- **Neon topbar**: Loading indicator uses green-to-purple-to-cyan gradient

### Sidebar

- Brand: `AGENTMANCER` with `.tm-brand` class (green glow effect)
- Nav items use left border accent on hover/active
- User email prefixed with green `$` terminal prompt
- Section labels are uppercase mono at 30% opacity

### Adding New Pages

When creating new LiveView pages:

1. Wrap content in `<Layouts.app flash={@flash} current_scope={@current_scope}>`
2. Use `<.header>` for page titles (automatically gets mono font)
3. Use daisyUI semantic classes — the CSS overrides handle the Technomancer styling:
   - Cards: `card bg-base-200` (gets gradient background + green border from CSS)
   - Stats: `stat bg-base-200 rounded-lg`
   - Buttons: `btn btn-primary`, `btn btn-ghost`, `btn btn-error btn-outline`
   - Tables: `table table-zebra` (gets green headers from CSS)
   - Badges: `badge` with `badge-success`, `badge-error`, `badge-warning`, `badge-ghost`
   - Tabs: `tabs tabs-bordered` with `tab-active`
4. Do not add custom colors or override the theme inline — use the daisyUI semantic color classes (`text-primary`, `bg-base-200`, `text-base-content/60`, etc.)
5. **All field groups must be in cards**: Forms, tables, filter groups, and data lists must always be wrapped in `<div class="card bg-base-200"><div class="card-body">...</div></div>`. Use `<h3 class="card-title text-sm">` for the card heading. No bare forms or tables floating outside cards.

### CSS Architecture

```
assets/css/app.css
├── Tailwind + daisyUI imports
├── daisyUI theme plugin (single "technomancer" theme)
├── Phoenix LiveView custom variants
├── Custom CSS sections:
│   ├── Font imports + typography
│   ├── Hex grid background + CRT scanlines
│   ├── Glow utility classes
│   ├── Sidebar styling
│   ├── Cards / arcane panels
│   ├── Stat panels
│   ├── Buttons, tables, inputs
│   ├── Badges, tabs, modals
│   ├── Steps/timeline, alerts
│   ├── Custom scrollbar
│   ├── Animations (pulse-glow, arcane-spin)
│   ├── Links, dividers, code blocks
│   └── Selection highlight, topbar, .text-brand
```
