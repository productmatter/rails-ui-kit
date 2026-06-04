# Changelog

All notable changes to rails-ui-kit are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project follows semantic versioning per [`RELEASING.md`](./RELEASING.md).

## [Unreleased]

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
