# Changelog

All notable changes to rails-ui-kit are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project follows semantic versioning per [`RELEASING.md`](./RELEASING.md).

## [Unreleased]

### Added
- Design tokens in `app/assets/tailwind/rails_ui_kit/engine.css` — shadcn/ui's CSS-variable names verbatim with Product Matter's own `oklch()` values, defined under `:root` and redefined under `.dark`, and mapped through `@theme inline` so `bg-primary`, `text-muted-foreground`, `border-border`, `ring-ring` and their siblings compile. A host app reskins the kit by redefining the same variable names after the import; an external shadcn theme drops in unchanged. `--radius` drives the `rounded-*` scale and resolves to Tailwind's own defaults at its shipped value, so no existing component's radius changes.
- `Ui::Base` — the shared component foundation. A class-level `class_variants` declaration wraps `ClassVariants.build`, and the resolved classes are merged through a single process-wide `TailwindMerge::Merger` with the caller's `class:` merged last, so a caller's utility replaces a conflicting variant default instead of racing it in stylesheet order. Also carries generic HTML attribute forwarding (`data:`/`aria:` hashes merge by key) and the `data-slot` styling hook.
- `Ui::ButtonComponent` — six variants (`default`, `destructive`, `outline`, `secondary`, `ghost`, `link`) across four sizes (`default`, `sm`, `lg`, `icon`). Renders a `<button>`, or an `<a>` when given `href:`. Token-backed focus-visible ring, disabled styling for both element forms, and automatic sizing for an unsized inline `<svg>` child. A disabled `href` button drops its href and reports `role="link" aria-disabled="true"`, so it is inert without JavaScript.
- `class_variants` and `tailwind_merge` as runtime dependencies.
- Button page in the `examples/` docs app.

### Changed
- `README.md` component table now lists `Ui::PopoverComponent` and `Ui::TooltipComponent`, which shipped in 0.2.0 but were never added, alongside the new `Ui::ButtonComponent`. Added a design-tokens and class-merge section under Overriding.

## [0.2.0] - 2026-06-04

### Added
- `Ui::TooltipComponent` with `ui--tooltip` controller — hover/focus-triggered text tooltip using Floating UI. Sets `role="tooltip"` and `aria-describedby` automatically. Supports all 12 Floating UI placements with auto-flip and shift middleware.
- `Ui::PopoverComponent` with `ui--popover` controller — click-triggered floating panel for rich HTML content. Click-outside and Escape-to-close. Manages `aria-expanded` and `aria-haspopup` on the trigger.
- `app/assets/tailwind/rails_ui_kit/engine.css` — Tailwind 4 entry point auto-discovered by `tailwindcss-rails` 4.x. Registers `@source` directives for the gem's component templates, Ruby class-list constants, and Stimulus controllers, and re-imports the modal transform-state classes. Consumers `@import` the build artifact (`app/assets/builds/tailwind/rails_ui_kit.css`) emitted by `tailwindcss:engines` instead of relying on a vendor-copy task.
- `RELEASING.md` documenting the release-and-tag procedure for this internal gem.
- `CHANGELOG.md` (this file).

### Removed
- `app/assets/stylesheets/rails_ui_kit/index.css`. Its `@import "rails_ui_kit/index"` entrypoint did not resolve under Tailwind 4's CLI; replaced by the `tailwindcss-rails` engine convention above.

### Changed
- `lib/rails_ui_kit/engine.rb` importmap initializer now guards on `defined?(Importmap::Engine)` instead of the bare `Importmap` constant, removing a boot-order race.
- `rails_ui_kit.gemspec` pins `view_component` to `>= 3.0, < 5.0` to prevent silent upgrades to an untested major version.
- `dialog_controller.js`, `toast_container_controller.js`, and `turbo_confirm_controller.js` now save and restore the global hooks they install (`window.defaultConfirmDialog`, `window.customConfirmDialog`, `window.triggerToast`, `Turbo.config.forms.confirm`) instead of unconditionally deleting or overwriting them. Multiple-instance and reconnect cases no longer leave the page with broken globals.
- `turbo_confirm_controller.js` now no-ops with a console warning when Turbo is not loaded, instead of throwing.

## [0.1.0] - 2026-05-01

Initial release. Internal gem; not published to RubyGems.

### Added
- `Ui::ModalComponent` with `ui--modal` controller — 8-position modal dialog, backdrop, form-change tracking, Turbo Frame integration.
- `Ui::DropdownComponent` with `ui--dropdown` controller — Floating-UI-positioned dropdown with keyboard navigation; menu, listbox, and dialog modes.
- `Ui::ConfirmDialogComponent` with `ui--dialog` controller — native `<dialog>` with a Promise-based API and global helpers (`window.defaultConfirmDialog`, `window.customConfirmDialog`).
- `Ui::ToastComponent` and `Ui::ToastContainerComponent` with `ui--toast` and `ui--toast-container` controllers — auto-dismissing notifications, client-side render from per-type `<template>` clones, custom-event and `window.triggerToast` triggers.
- Utility controllers: `ui--form-change` (dirty-form tracking), `ui--turbo-confirm` (Turbo confirm interception), `ui--turbo-disable-with` (form-element disable styles), `ui--dark-mode` (theme toggle with localStorage and OS-preference fallback).
- Importmap pins for `@floating-ui/dom` shipped via the engine.
- Component-level Minitest coverage via a dummy app under `test/dummy`.
- CI matrix on Ruby 3.1, 3.2, 3.3, 3.4, and 4.0.
