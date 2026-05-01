# Changelog

All notable changes to rails-ui-kit are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project follows semantic versioning per [`RELEASING.md`](./RELEASING.md).

## [Unreleased]

### Added
- `app/assets/stylesheets/rails_ui_kit/index.css` Tailwind 4 entry point that registers `@source` directives for the gem's component templates and Stimulus controllers, ensuring utility classes survive Tailwind's content scan in consumer apps.
- `RELEASING.md` documenting the release-and-tag procedure for this internal gem.
- `CHANGELOG.md` (this file).

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
