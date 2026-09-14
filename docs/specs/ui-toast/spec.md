---
slug: ui-toast
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-14
loop_budget: 6
---

## Intent

**A toast says what happened, and sometimes offers one thing to do about it.** Jonathan
asked for a toast that supports a title, a description, actions and a countdown. Content
given on its own becomes the description. A title sits above the description, and actions
sit in a footer when the payload has them.

Toast passes rule 0 twice. Gate 1: it is how a Rails app shows `flash` and answers a Turbo
Stream. Gate 2: its timing and announcements are genuinely hard to get right, and the
action is where most toast libraries get them wrong.

**What is true today** (verified against the code on 2026-09-14, with `spec-localization`'s
in-progress `close_label:` work in the tree):

- `Ui::ToastComponent < ViewComponent::Base`, not `Ui::Base`. It takes
  `initialize(type:, message:, close_label: nil, default_title: nil)`, has five `TYPES`
  (`success error notice alert info`), and paints them with hardcoded palette pairs
  (`bg-green-100 dark:bg-green-900/30`, `text-red-400 dark:text-red-500` and their kin) on a
  `bg-white dark:bg-gray-800` shell. That breaks parent rules 1 and 5: there is no `class:`
  to merge.
- `normalize_message` takes a Hash (deep-symbolized, keys `title`/`body`/`timeout`), an
  I18n key (a Hash translation is the payload, a String translation is the title), or a
  String, which **becomes the title**. Anything else gets the chrome `default_title`.
- There is no action of any kind.
- `toast_controller.js` already has most of a countdown. `connect()` announces the toast,
  then arms `setTimeout(close, selfDestruct)` and runs a CSS `scale` transition on the
  `timer` target over the same duration. `mouseenter`/`mouseleave` and
  `focusin`/`focusout` (ignoring focus moving inside the toast) pause and resume it. Pausing
  stores the remaining milliseconds and freezes the bar at its computed `scale`. Resuming
  re-arms for the remainder and restarts the bar from where it froze. `close()` swaps
  enter/leave classes and removes the element after a fixed `setTimeout(500)`. That's a
  hand-rolled presence, which parent rule 4 forbids. `selfDestruct` of `0` means no timer
  at all. Defaults are 20 000 ms for `error` and 3 000 ms for everything else, in Ruby
  and in JavaScript alike. Nothing honours `prefers-reduced-motion`, and nothing pauses
  while the tab is hidden.
- A toast announces itself by writing `title. body` into one of the container's two
  persistent live regions (assertive for `error`, polite otherwise), clearing it first
  so a repeat is announced again. The toast element has no role.
- **Three entry points:**
  1. **Ruby render:** `render Ui::ToastComponent.new(type:, message:)`.
  2. **Turbo Stream:** the documented recipe is `turbo_stream.append "body"`, wrapping a
     rendered `Ui::ToastComponent` (`examples/app/helpers/code_examples_helper.rb`,
     `example_toast_stream`). **That's a defect.** The toast lands at the end of
     `<body>`, outside `Ui::ToastContainerComponent`'s fixed stack, so it renders in page
     flow wherever the body ends. The stack has no `id` to target.
  3. **JavaScript:** `window.triggerToast(type, message)`, installed by
     `toast_container_controller.js` on connect and restored on disconnect, plus the
     `rails-ui-kit:toast` document event with `detail: { type, message }`. Both clone a
     per-type `<template>` the container rendered from `Ui::ToastComponent`, write
     `textContent` into the `title`/`body` targets, and write the self-destruct value.
- **No flash integration exists.** Nothing in `app/` or `lib/` reads `flash`. The docs
  app's own flash is a hand-written `turbo_stream.update "flash"`.

**What this scope is.** One payload, and every entry point renders exactly that payload
into exactly the same markup. Actions go through `Ui::ButtonComponent`. The type glyph is a
default the caller can replace or remove, not structure they're stuck with. The timing defaults
never let a toast take its action away from a keyboard or screen-reader user. Toast moves
onto `Ui::Base`, the tokens and Primitive D. That last part is `ui-foundation-retrofit`'s
Toast half, taken over here so the template is rewritten once, not twice (§ Assumptions).

**Appetite.** One component pair, two controllers, one Turbo Stream helper, six kit
extension tokens, two chrome strings, and the docs page. No queue, no flood control, no
swipe-to-dismiss.

## Goal

A toast built from one plain-data payload renders identically from Ruby, a Turbo Stream
and JavaScript, on tokens and `Ui::Base`. It shows a title over a description, with
actions in a footer rendered by `Ui::ButtonComponent`. A toast with an action stays until
someone dismisses it, and a keyboard user can reach that action. Every countdown pauses on
hover, on keyboard focus and while the page is hidden. An `href` that isn't relative or
`http(s)` never reaches the DOM. This is established when every agent-loopable check in
§ Acceptance checks passes.

## Non-goals

- **Rich content in the description.** The payload is text. Markup a caller passes in a
  Ruby block renders in Ruby, but no payload carries HTML, because the JavaScript path
  writes `textContent` and must match.
- **Callbacks.** An action is a URL, a method, or a dismissal. No payload carries a
  function, because a payload crosses into flash and JSON.
- **A custom icon from JavaScript or flash.** A replacement glyph is markup, so it comes
  only from a Ruby render's `icon` slot. A payload can keep the type's glyph or remove it,
  nothing else.
- **A flash component.** The payload is flash-safe and the docs show the three-line
  layout recipe. A component that maps `flash` automatically is the parent's "flash
  banner", not planned (`ui-component-library` § Out of scope).
- **Queueing, deduplication, a maximum stack, swipe gestures, promise toasts, positions
  other than the container's.** None has a pulling client need.
- **Toasts that survive a Turbo Drive visit.** The container lives in the layout body and
  is replaced on visit, as today. A flash on the next page is how a message crosses a
  redirect.

## Behavior

1. **One payload.** A toast is a Hash of plain data, the same keys everywhere:

   | Key | Type | Meaning |
   |---|---|---|
   | `type` | `success` `error` `notice` `alert` `info` | Colour, glyph, and which live region announces it. Unknown → `info` (unchanged). |
   | `title` | String | Optional. The first line, emphasised. |
   | `description` | String | Optional. Below the title, or on its own. |
   | `actions` | Array of action Hashes (item 6) | Optional. Rendered in a footer. |
   | `duration` | Integer, milliseconds | Optional. `0` persists. Absent means the default (item 10). |
   | `icon` | `false` | Optional. `false` removes the glyph. Absent keeps the type's glyph. No other value (item 11). |

   Every key is one lowercase word, so one spelling serves Ruby keywords, JSON, a flash
   stored in a cookie session and a JavaScript object literal. (The shared rule is
   lowercase `snake_case`, § Business rules, rule 1. Toast happens to need no two-word
   key.) Keys may be strings or
   symbols, and values may be strings where a symbol is expected (`"success"`), because
   a flash that round-trips a JSON session comes back that way. A payload is never a
   component instance.

2. **Content becomes the description.** Wherever a caller gives content without naming
   it, it's the description:
   - Ruby: `Ui::ToastComponent.new(type: :success, message: "Saved")`, or a block
     (`render(Ui::ToastComponent.new(type: :success)) { t(".saved") }`).
   - JavaScript: `window.triggerToast("success", "Saved")`, and the event with
     `detail: { type: "success", message: "Saved" }`.
   - An I18n key given as `message:` whose translation is a String. A Hash translation is
     still read as a payload, and the lookup itself is unchanged.

   `message:` stays as the 0.2.0 keyword. A String is content; a Hash is a payload. **This
   reverses 0.2.0, where a plain String became the title.** The upgrade note is item 17.

3. **Entry point 1: Ruby.** `Ui::ToastComponent.new(**payload, close_label:,
   default_title:, actions_hint:, **html_attributes)`. `class:` merges onto the root
   through `Ui::Base` (parent rule 5). An `icon` slot replaces the type's glyph with the
   caller's own (`toast.with_icon { render MyIconComponent.new }`), and `icon: false` removes
   it. Passing both is invalid (item 15). `Ui::ToastContainerComponent.new(toasts: [...])`
   takes an Array of payloads, string keys included, and renders them inside its stack on
   page load. That's the flash path:

   ```erb
   <%= render Ui::ToastContainerComponent.new(toasts: [flash[:toast]].compact) %>
   ```
   ```ruby
   redirect_to @project, flash: { toast: { type: "success", title: "Project archived",
     actions: [{ label: "Undo", href: unarchive_project_path(@project), method: "patch" }] } }
   ```

4. **Entry point 2: Turbo Stream.** `turbo_stream.ui_toast(payload)` appends a rendered
   `Ui::ToastComponent` to the container's stack, whose `id` is `ui-toasts`. It uses
   Turbo's built-in `append`, not a custom action, so it needs no client registration and
   is validated in Ruby like entry point 1. It joins `RailsUiKit::TurboStreams` beside
   `ui_close_modal`, through the same load hook:

   ```erb
   <%= turbo_stream.ui_toast(type: :success, description: "Record saved.") %>
   ```

   The docs' `turbo_stream.append "body"` recipe is replaced.

5. **Entry point 3: JavaScript.** `window.triggerToast(payload)`, or the 0.2.0 form
   `window.triggerToast(type, content)`, where content is a String (item 2) or a payload
   without `type`. The `rails-ui-kit:toast` event takes the payload as `detail`, and still
   accepts the 0.2.0 `{ type, message }`:

   ```js
   window.triggerToast({ type: "success", title: "Project archived",
     actions: [{ label: "Undo", href: "/projects/7/unarchive", method: "patch" }] })
   ```

6. **An action.** `{ label:, href:, method:, variant:, class:, dismiss: }`. Every one is
   rendered by `Ui::ButtonComponent` at `size: :sm`, so it inherits Button's tokens, dark
   mode, focus outline and contrast:

   | Key | Default | Meaning |
   |---|---|---|
   | `label` | required | The visible text and accessible name. Content: the host translates it. |
   | `href` | none | A URL (item 9). |
   | `method` | `get` | `get` `post` `patch` `put` `delete`, case-insensitive. |
   | `variant` | `outline` | One of Button's variants: `default` `destructive` `outline` `secondary` `ghost` `link`. |
   | `class` | none | Merged onto Button's classes with `tailwind_merge`, so the caller wins. Ruby and Turbo Stream only (item 8). |
   | `dismiss` | `true` | Whether activating it closes the toast. |

   What each renders:
   - **`href`, `get`:** Button's `<a href>`.
   - **`href`, any other method:** a `<form method="post" action="href" data-turbo="true">`
     with a hidden `_method` (omitted for `post`) around Button's `<button type="submit">`.
     This is Rails' `button_to` shape, **not** a `data-turbo-method` link, for three
     reasons. It is announced as a button, which is what an Undo is. With JavaScript or
     Turbo absent, it fails as a rejected POST, not as a GET to a mutating URL. And it is
     the form Turbo builds from such a link anyway (verified in the bundled turbo-rails
     2.0.23: `FormLinkClickObserver` builds exactly this `<form data-turbo="true">`). No
     authenticity-token field is rendered in any path: Turbo sends `X-CSRF-Token` from the
     page's `csrf-token` meta on every non-GET submission (verified,
     `FormSubmission#prepareRequest`). That keeps the markup identical from all three entry
     points.
   - **No `href`:** Button's `<button type="button">`, a dismiss-only action ("Got it").
     `dismiss` is forced `true`. `dismiss: false` or a `method` without an `href` is
     invalid (item 15), because that action would do nothing.

   Dismissal on activation never removes the element synchronously. The toast exits
   through Primitive D after the click has reached Turbo's document-level listeners, so a
   link is followed and a form is submitted before the element leaves.

7. **The same markup from every entry point.** Ruby renders a toast. A Turbo Stream renders
   the same component. JavaScript never composes classes or markup. It clones
   server-rendered `<template>`s, writes text, `href`, `action`, the `_method` value and
   data attributes into them, and removes a part the payload leaves out (the glyph for
   `icon: false`, the description, the footer). The container renders one toast template per type, as
   today, and one action template per Button variant and element kind (link, button, form
   shell). Each action template comes from `Ui::ButtonComponent` itself, so an action
   JavaScript builds carries Button's exact classes and attributes, and a change to Button
   reaches it with no JavaScript edit. Generated `id`s (item 11) are the only thing that
   differs.

8. **Where `class:` can't go.** A browser has no `tailwind_merge`, and the kit won't ship a
   second merge implementation whose output could differ from the gem's (parent rule 8).
   So a JavaScript payload whose action carries `class` is invalid (item 15), not appended
   unmerged. Appended classes would resolve by stylesheet order, not by the caller, and
   silently break rule 5. Decided 2026-09-14 by the orchestrator's ratifying ruling
   (`open-questions.md`): `class` is a Ruby and Turbo Stream key only.

9. **The URL rule.** An `href` is allowed when it is a relative reference (`/p`, `p`,
   `?q`, `#f`, `//host/p`) or an absolute `http:`/`https:` URL. Anything else is rejected:
   `javascript:`, `data:`, `vbscript:`, `blob:`, `file:`, `mailto:`, `tel:`. Ruby and
   JavaScript decide the same way. First strip leading and trailing C0 controls and
   spaces, and remove every ASCII tab and newline, as the WHATWG URL parser does. Then any
   string that starts with a scheme (`[A-Za-z][A-Za-z0-9+.-]*:`) must be `http` or `https`,
   case-insensitive. JavaScript then confirms with `new URL(href, document.baseURI)`.
   Both implementations run one shared list of vectors (§ Acceptance checks), including
   `JaVaScRiPt:`, `" javascript:"`, `"java\tscript:"` and `"javascript:"`. Rejection
   follows item 15: loud in development and test, the action dropped in production.

10. **Timing defaults.**
    - **A toast with at least one action doesn't auto-dismiss** unless the payload sets
      `duration`. WCAG 2.2.1: a keyboard user has to reach the toast first (item 12), and
      a screen-reader user hears it before they can act. No default is long enough for
      both, and a toast that takes its Undo away is worse than one that waits.
    - **A toast with no action** keeps 0.2.0's defaults: 20 000 ms for `error`, 3 000 ms
      otherwise. Its words are in the live region whether or not the card is still on
      screen, and it offers nothing to reach.
    - **An explicit `duration` wins**, actions or not, and `0` persists. The docs say a
      timed toast with an action is the caller's accessibility decision to own.
    - **Every countdown pauses** while the pointer is over the toast, while focus is
      inside it, and while `document.visibilityState` is `hidden`. It resumes with the
      time that was left. Hover and focus exist today. Hidden is new, because a toast
      fired into a background tab would otherwise expire unseen.

11. **Layout.** On tokens only, with logical properties only, and no `dark:` class in
    either component:
    - The root is `role="group"`, `aria-labelledby` the title (the description when there
      is no title) and `aria-describedby` the description when both exist. It's a
      `bg-popover text-popover-foreground` surface with a `border-border` edge, the kit
      radius and a shadow, and `data-slot="toast"`. A group, so a user whose focus lands
      on an action hears whose action it is. It is not a live region (item 13).
    - A grid: the glyph cell, the text column, and the close button at the inline-end,
      aligned to the first line. The glyph cell (`data-slot="toast-icon"`, `aria-hidden`)
      holds the type's glyph by default, or the caller's `icon` slot content. Either way it
      sets the type's token as `currentColor`, so a caller's `stroke="currentColor"` SVG
      takes the type colour. With `icon: false` the cell isn't rendered, and the text
      column starts at the inline-start padding. The type is never carried by the glyph
      alone: its words and, for `error`, the assertive region carry it.
    - **Text column:** the title (`<p>`, `font-medium`) stacked above the description
      (`<p>`, `text-muted-foreground`). With no title, the description takes the first line
      in `text-popover-foreground`, so a one-line toast doesn't read as secondary. With
      neither, the chrome `default_title` is the title, as today. Both are `min-w-0
      wrap-break-word`: long text wraps, never truncates, and never clamps
      (`ui-localization` § Behavior, item 12).
    - **Footer** (`data-slot="toast-actions"`), present only when there are actions. It
      sits below the text column, aligned with its inline-start, `flex flex-wrap
      justify-end gap-2`. Actions wrap between one another. A label keeps Button's
      no-wrap, fixed-height contract. The root doesn't clip its content, so a label too
      long for the toast overflows visibly instead of being cut. Shortening it is the
      host's job, as it is for any Button.
    - **Close button:** `Ui::ButtonComponent` `variant: :ghost`, `size: :icon`, sized to
      `--control-height-sm` (32 px, above WCAG 2.5.8's 24 px), `aria-label` from
      `close_label`. It's separate from the footer and present on every toast.
    - **Countdown bar** (item 12), when there is a countdown: along the block-end edge,
      inset to the root's radius instead of relying on clipping.
    - The container keeps `fixed top-4 inset-e-4` and gains `max-w-[calc(100vw-2rem)]`, so
      a 320 px viewport doesn't overflow.

12. **Reaching a toast.** Toasts announce without taking focus, so the kit gives a keyboard
    user a way in:
    - While it holds a toast, the stack is a `role="region"` landmark named by
      `region_label` ("Notifications"), with `aria-keyshortcuts="F8"`. Empty, it is
      `hidden`, so a landmark list doesn't carry an empty region.
    - **F8** from anywhere moves focus to the newest toast's first action, or to its close
      button if it has none. It records where focus came from. With no toast, F8 isn't
      intercepted. F8 isn't a character key, so WCAG 2.1.4 doesn't apply. Tab reaches the
      stack in DOM order too.
    - **Escape** with focus inside a toast closes it. A toast closed while it holds focus,
      by Escape, its close button or a dismissing action, returns focus to where F8
      recorded it came from, if that element is still connected. Otherwise focus goes to
      the next-newest toast, and failing that to `document.body`.
    - **Over an open Modal: occluded, not promoted.** The top-layer reachability probe
      (the first agent-loopable check) **failed** on 2026-09-14 in headless Chrome 152. A
      `popover="manual"` element shown after a modal `<dialog>` opens is painted above it
      but is still blocked by the modal: not hit-tested, a click lands on the dialog, and
      `focus()` is refused. A bare `<dialog>` does the same, so this is the platform, not the
      kit Modal's code. Following the orchestrator's verify-first ruling
      (`open-questions.md`), promotion isn't built. The container stays in normal flow
      with one static stacking value from the kit's CSS. Toasts are occluded while a
      Modal is open. An action toast, which persists by default, becomes reachable when
      the Modal closes. A toast action a user can see but can't reach is worse than one
      hidden behind the modal.
    - **The docs say plainly that a toast action must never be the only way to do
      something.** A toast can be missed, closed or occluded (§ Assumptions), so every
      action it offers exists somewhere on the page too.

13. **What is announced.** Once, when the toast connects, in the existing live region for
    its type: `title. description`. When the toast has actions, the chrome `actions_hint`
    follows ("Press F8 to reach its actions."). Nothing else is announced. The countdown
    isn't announced, nor are pause, resume or dismissal. A number read out every second
    would drown the page, and the words already persist in the live region.

14. **The countdown, when there is one.** The bar is the visible remaining time,
    `aria-hidden`, coloured by the type's token over a 20% tint of it. It freezes while
    paused and continues from there on resume, as it does today.
    Under `prefers-reduced-motion: reduce` it has no transition. Instead it steps to the
    remaining fraction once per second. The dismissal timing doesn't change. Enter and
    exit move from the controller's class-swap-and-`setTimeout(500)` to Primitive D
    (`overlay/presence.js`, `enter`/`exit`), which already honours reduced motion, and
    `data-state` drives the CSS.

15. **Invalid input: loud in development and test, safe in production.** The kit's existing
    pattern (`Ui::Base.raise_on_unknown_variant?`) applies to every payload rule here. That
    covers an unknown key, a blank action `label`, an unknown `variant` or `method`, a
    rejected `href`, `dismiss: false` or a `method` without an `href`, a `class` in a
    JavaScript action, a non-integer or negative `duration`, an `icon` value other than
    `false`, and an `icon` slot together with `icon: false`.
    - **Ruby** raises `ArgumentError` subclasses that name the key and the fix. In
      production it logs the same message through `Rails.logger.warn` and renders safely.
      An invalid action is dropped. An unknown key is ignored. An invalid `duration` uses
      the default.
    - **JavaScript** can't see `Rails.env`, so the container renders
      `data-ui--toast-container-strict-value` from that same predicate. Strict,
      `triggerToast` throws before anything renders. Not strict, it `console.warn`s and
      renders safely by the same rules.
    - **0.2.0's `body` and `timeout`** get a message naming `description` and `duration`.
      In production they're still honoured as those keys, with the warning.

16. **Chrome strings.** They follow `ui-localization` (call site → host locale →
    kit default). The two new strings join `rails_ui_kit.en.yml` and its docs table:
    `toast.region_label` ("Notifications") and `toast.actions_hint` ("Press F8 to reach its
    actions."). Keywords are the key's leaf. `Ui::ToastComponent` takes `close_label:`,
    `default_title:` and `actions_hint:`. `Ui::ToastContainerComponent` takes those three
    plus `region_label:`, because JavaScript-created toasts are clones of its templates
    and read its values. That's the same reasoning `spec-localization` applied to
    `close_label:`, extended, not replaced. The live-region text is built from rendered
    text and resolved strings, never from an English literal.

17. **The upgrade note.** `UPGRADING.md` gains this entry, and the grep checklist gains its
    lines:

    > ## A toast's plain message is now its description, not its title (visible, not loud)
    >
    > `Ui::ToastComponent.new(type: :success, message: "Saved")`,
    > `window.triggerToast("success", "Saved")` and a `rails-ui-kit:toast` event whose
    > `message` is a string used to render "Saved" as the toast's bold title. It is now the
    > description: regular weight, and in the main text colour when there's no title. Nothing
    > errors, and a screen reader hears the same words.
    >
    > **To keep the old look,** name it a title: `message: { title: "Saved" }` or
    > `triggerToast("success", { title: "Saved" })`.
    >
    > **Renamed, loud in development:** `body:` is `description:` and `timeout:` is
    > `duration:` (`duration: 0` still persists). In development and test the old keys raise,
    > or throw in JavaScript, naming the new one. In production they still work and log a
    > warning.
    >
    > **In your tests,** `data-ui--toast-target="body"` is now `description`, and a
    > string toast's text is in `description`, not `title`.
    >
    > **Also:** an `alert` toast is now the destructive colour, not orange. A toast with an
    > action stays until it's dismissed. `container_class:` now adds to the container's
    > classes instead of replacing them. A toast sent by Turbo Stream should use
    > `turbo_stream.ui_toast`, because `turbo_stream.append "body"` puts it outside the
    > container.
    >
    > ```bash
    > grep -rn 'triggerToast\|ToastComponent.new\|rails-ui-kit:toast' app/ | grep -v 'title'
    > grep -rn 'body:\|timeout:' app/ | grep -i toast
    > grep -rn 'ui--toast-target="\(title\|body\)"' app/ test/ spec/
    > ```

## Business rules

These refine `ui-component-library` § Business rules, rules 1, 4, 5 and 6, and weaken
none. **Rules 1 to 5 are the shared convention for any kit component that JavaScript
reconfigures or builds.** `ui-confirm-dialog` adopts them and doesn't restate them.

**Must**

1. **A payload is plain data.** Strings, integers, booleans, arrays and hashes whose keys
   are lowercase `snake_case`, spelled identically in Ruby, JSON, flash, JavaScript and,
   dasherized, in a data attribute. No component
   instance, function or markup string is ever a payload value.
2. **JavaScript never composes classes or markup.** It clones or toggles markup a component
   rendered on the server, and writes only text, URLs and data attributes. Every class a
   kit element carries was resolved in Ruby.
3. **A kit button is `Ui::ButtonComponent`,** in every entry point. That covers a toast
   action, the close button, and a dialog's confirm and cancel. A variant JavaScript can
   choose is a server-rendered alternative it swaps in, never a class list it writes.
4. **Invalid input is loud in development and test and safe in production,** in both
   languages. The strict flag JavaScript reads is rendered from
   `Ui::Base.raise_on_unknown_variant?`, never inferred in the browser.
5. **No component forces iconography** (decided 2026-09-14, Jonathan Simmons). A kit
   glyph is at most a default. A caller replaces it through a Ruby slot or removes it with
   `icon: false`. An icon is `aria-hidden`, and meaning is carried by the words: a title, a
   description, a label. Custom icon content comes only from a Ruby render. No JavaScript
   payload carries SVG or any other markup.
6. **Any `href` from a payload is relative or `http(s)`,** decided by one rule in both
   languages and tested against one shared list of vectors (§ Behavior, item 9).
7. **An action is never taken away by a default.** A toast with an action has no countdown
   unless its payload asks for one.
8. **Every countdown pauses for hover, keyboard focus and a hidden page,** and resumes with
   the remaining time.
9. **No toast is shown where its action can't be reached.** The container is promoted
   above a Modal only once the top-layer reachability probe has passed in the browser lane.
   It failed on 2026-09-14, so occlusion is the behaviour (§ Behavior, item 12).
10. **The same payload renders the same markup from all three entry points,** generated ids
   aside.
11. **Toast has no class-string theming keyword that replaces classes.** A class a caller
    passes, `class:`, `container_class:` or an action's `class`, merges with
    `tailwind_merge` onto the defaults.

**Should**

12. **Adopt the platform and the kit.** Primitive D for enter and exit, Turbo's own
    `append` and CSRF header, the live regions the container already renders. No second
    timer or presence implementation.

## Assumptions

- **This scope takes over Toast's half of `ui-foundation-retrofit`.** That's the token
  migration, `Ui::Base`, the presence primitive, and the retrofit's open question about
  toasts over an open Modal (moved to this scope's `open-questions.md`). The retrofit's
  spec, `implementation.md` and `open-questions.md` were trimmed to match on 2026-09-14. Its ratified token
  mapping is inherited unchanged: `error`/`alert` → `destructive`, `success` → `success`,
  `notice` → `warning`, `info` → `info`. `--success`, `--warning` and `--info` land here
  with their `-foreground` pairs, as kit extensions in the kit's low-priority token layer
  (`ui-design-tokens` § Business rules, rules 5 and 7). They ship with `.dark` values, a
  glyph and bar contrast of at least 3:1 against `--popover`, and a foreground contrast of
  at least 4.5:1 on its fill. Toast consumes only the base token, but the pair is the
  contract a shadcn theme author expects. This scope also replaces two retrofit
  commitments on purpose: retrofit rule 8's "toast contracts keep working exactly as
  documented" (§ Behavior, item 2 changes one), and the byte-for-byte `title`/`body`
  target names (`body` becomes `description`). **At a contradiction**, where the retrofit
  build has already migrated Toast, this scope builds on its tokens and doesn't redo them.
- **`spec-localization`'s `close_label:` work lands first.** This scope extends the
  `Ui::Chrome` concern and the container's templates-carry-chrome reasoning. It doesn't
  reshape them. **At a contradiction**, a different chrome mechanism at build time, follow
  it and re-point item 16.
- **Turbo's behaviour, as verified in the bundled turbo-rails 2.0.23.** `append` to an `id`
  needs no custom action. A non-GET `FormSubmission` adds `X-CSRF-Token` from the meta tag.
  A `_method` field or a named submitter overrides the method. Link clicks are handled by a
  bubbling `click` listener on the document. **At a contradiction** after a Turbo upgrade,
  escalate rather than reintroducing an authenticity-token field in one path only.
- **An open modal `<dialog>` makes the rest of the document inert, and top-layer promotion
  doesn't escape it.** Verified 2026-09-14 in headless Chrome 152 by the top-layer
  reachability probe: a `popover="manual"` element shown above an open modal is painted but
  not hit-testable or focusable, with the kit Modal and with a bare `<dialog>`. Safari and
  Firefox weren't probed. Because promotion isn't built, no engine can do better than the
  fallback in § Behavior item 12, which applies to every browser. Don't add a focus
  exception or per-engine branching.
- **`message:` I18n lookup is 0.2.0 behaviour and kept.** A String that happens to be a key
  (Rails' default `en.hello`) is translated. It is recorded, not changed.

## Critical files

- `app/components/ui/toast_component.rb` and `.html.erb`, `toast_container_component.rb`
  and `.html.erb`: the subject.
- `app/javascript/rails_ui_kit/controllers/toast_controller.js`,
  `toast_container_controller.js`: timing, focus, cloning, validation.
- `app/javascript/rails_ui_kit/overlay/presence.js`: Primitive D, consumed.
- `app/components/ui/button_component.rb`: the action and close-button renderer; read, not
  changed.
- `app/components/ui/base.rb`: `raise_on_unknown_variant?`, the strict predicate.
- `app/components/ui/chrome.rb`, `config/locales/rails_ui_kit.en.yml`: the two new strings.
- `lib/rails_ui_kit/turbo_streams.rb`: `ui_toast` beside `ui_close_modal`.
- `app/assets/tailwind/rails_ui_kit/engine.css`: the six kit extension tokens and their
  `@theme inline` mappings.
- `test/components/ui/toast_component_test.rb`, `toast_container_component_test.rb`,
  `test/system/toast_test.rb`, `test/i18n/chrome_contract_test.rb`,
  `test/components/ui/chrome_override_test.rb`, `test/system/tokens_test.rb`.
- `examples/app/views/docs/toast.html.erb`, `examples/app/helpers/code_examples_helper.rb`,
  `README.md` (Triggering toasts), `CHANGELOG.md`, `UPGRADING.md`.

## Acceptance checks

### agent-loopable

- **Top-layer reachability probe: written and run first, before any toast code depends on promotion.** It uses no toast code, only the platform and the kit's real Modal. On the Modal docs page, open a `Ui::ModalComponent`. Insert a `<div popover="manual">` holding a `<button>` and an `<a href>`, and call `showPopover()` on it. Then check the following. `document.elementFromPoint` at the button's centre returns the button. A Capybara click fires its handler. After `focus()`, the button is `document.activeElement` and is still, 500 ms later, not reclaimed by the Modal's focus trap. An Escape keydown on the focused button that calls `preventDefault()` leaves the dialog open. Focusing back into the dialog afterwards works. The result, pass or fail, is recorded in status.md, and § Behavior item 12 follows the matching branch. **Result, 2026-09-14: failed at the first check.** The button isn't hit-tested, the click is intercepted by the dialog, and `focus()` is refused, so the later checks can't run. The test file now pins that finding: TP1 uses the kit Modal, TP2 a bare `<dialog>`, and TP3 is a no-modal control that proves the measurement can pass. Run: `bundle exec rake test:system TEST=test/system/toast_top_layer_probe_test.rb`
- Payload and layout in Ruby. A String `message:` and a block each render as the description, and neither renders a title. A title renders before the description in DOM order. With neither, `default_title` is the title. String keys and string values are accepted. Each action renders the same classes and attributes as `Ui::ButtonComponent.new(variant:, size: :sm)`. A `get` href is an `<a>`. A `patch` href is a `post` form with `_method=patch`, `data-turbo="true"` and no authenticity field. An action with no href is `<button type="button">`. An action's `class:` beats Button's own conflicting class. No action renders no footer. The type glyph renders by default. An `icon` slot replaces it inside the same `aria-hidden` cell. `icon: false` renders no `toast-icon` slot and no `<svg>` outside the close button. The root carries `role="group"` and never `role="status"`, `role="alert"` or `aria-live`. Run: `bundle exec rake test TEST=test/components/ui/toast_component_test.rb`
- Timing defaults in Ruby. No actions gives 3 000 ms, or 20 000 ms for `error`. Actions and no `duration` gives no self-destruct value and no countdown bar. An explicit `duration` wins with actions. `duration: 0` persists. Run: `bundle exec rake test TEST=test/components/ui/toast_timing_test.rb`
- The URL rule. Every vector in the shared list is accepted or rejected as listed by the Ruby implementation. Rejection raises in test, and under a stubbed production predicate it drops the action and logs. Run: `bundle exec rake test TEST=test/components/ui/toast_href_test.rb`
- The same list through `window.triggerToast`, strict and not strict. A rejected href throws and renders nothing when strict. It renders the toast without that action and warns when not. No `javascript:` URL is ever present in the DOM. Run: `bundle exec rake test:system TEST=test/system/toast_href_test.rb`
- Invalid input from every rule in § Behavior, item 15. It raises in Ruby and throws from JavaScript when strict, and when not strict it renders by the safe rule and warns. `body`/`timeout` name their replacements. A JavaScript action with `class` is rejected. Run: `bundle exec rake test TEST=test/components/ui/toast_validation_test.rb && bundle exec rake test:system TEST=test/system/toast_validation_test.rb`
- **The same payload renders identically from all three entry points.** Take two payloads, one with a title, a description and three actions (link, `patch` form, dismiss-only) and one timed with a description only and `icon: false`. Render each from `Ui::ToastContainerComponent.new(toasts:)`, from a `turbo_stream.ui_toast` response to a docs-app endpoint, and from `window.triggerToast(payload)`. After each toast's enter settles, the three toasts' `outerHTML` are equal once generated ids are normalised. The timed payload also excludes the bar's inline `scale`. The check is proved able to fail by planting one extra class on the JavaScript template. Run: `bundle exec rake test:system TEST=test/system/toast_entry_points_test.rb`
- **A toast with an action is still present, and its action reachable, after longer than any default duration.** Fire an actions toast with no `duration`. Advance past 20 000 ms, with Chrome DevTools Protocol virtual time or a clock the test controls, not a real sleep. The toast is still in the DOM. F8 focuses its first action. Enter on a `patch` Undo reaches the docs-app endpoint with `_method=patch` and a valid CSRF header, and the toast then closes. Escape on another closes it and returns focus to the element focused before F8. Run: `bundle exec rake test:system TEST=test/system/toast_reach_test.rb`
- **The countdown pauses on keyboard focus, not just hover.** A 2 000 ms toast is given focus by F8, with no pointer involved, and is still present 4 000 ms later with its bar's scale unchanged across that span. On blur it closes within its remaining time plus 300 ms. The same holds for pointer hover, and for `visibilityState` reported `hidden` with a `visibilitychange` dispatched. Under emulated `prefers-reduced-motion: reduce`, the bar's computed transition duration is `0s`, its scale changes at most once per second, and the toast still closes at its duration. Run: `bundle exec rake test:system TEST=test/system/toast_countdown_test.rb`
- Announcements. The polite region receives `Title. Description` once. An actions toast appends the resolved `actions_hint`. A `MutationObserver` on both regions records no further text change over a full countdown, a pause and a dismissal. Run: `bundle exec rake test:system TEST=test/system/toast_test.rb`
- Tokens and theming. No palette literal and no `dark:` utility in either toast component file. The six kit extension tokens exist under `:root` and `.dark`, and meet their contrast minimums in both modes. A host that redefines `--success` wins. `container_class:` merges. A toast with actions passes `assert_accessible` in light and dark. Run: `! grep -nE -- '-(white|black)\b|-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|green|blue|indigo)-[0-9]{2,3}\b|\bdark:' app/components/ui/toast_component.rb app/components/ui/toast_component.html.erb app/components/ui/toast_container_component.rb app/components/ui/toast_container_component.html.erb && bundle exec rake test:system TEST=test/system/tokens_test.rb && bundle exec rake test:system TEST=test/system/toast_accessibility_test.rb`
- Chrome strings. `region_label` and `actions_hint` are in the inventory and on the docs page, win per instance on both components, reach the attributes the controllers read, and switch with locale. Run: `bundle exec rake test TEST=test/i18n/chrome_contract_test.rb && bundle exec rake test TEST=test/components/ui/chrome_override_test.rb`
- A page with a toast visible, navigated away from and restored from Turbo's cache, shows no toast. Run: `bundle exec rake test:system TEST=test/system/toast_turbo_cache_test.rb`
- The whole suite stays green. The audit's toast guards (T1, T2) keep what they assert, and only selectors for the renamed `description` target change. Run: `bundle exec rubocop && bundle exec rake test && bundle exec rake test:system`

### judgeable

- The docs page, README and UPGRADING entry make three things impossible to miss: content
  is now the description, an action toast persists, and a toast action must never be the
  only way to do something. Judged against § Behavior, items 2, 10, 12 and 17.
- Toast's controllers keep no presence, timer-bar or class logic that Primitive D or a
  server-rendered template already provides. Judged against § Business rules, rules 2 and
  12, and parent rule 4.

### human-gate

- Jonathan views the docs page's toasts: title only, description only, title with
  description, with one and two actions, a long description, each type, in light and dark,
  LTR and RTL. He accepts the layout and the colour mapping.
- Jonathan, using VoiceOver, hears one announcement per toast and the actions hint, reaches
  an Undo with F8, and returns to his place with Escape.
- Promotion wasn't built (the probe failed), so there is no Safari or Firefox promotion gate.

## Out of scope / deferred

- **Timed toasts pausing while a Modal occludes them** isn't planned. Under promotion
  they aren't occluded. Under the fallback, a timed toast without actions carries nothing
  to reach, and its words are already in the live region.
- **`class` on a JavaScript action** is not planned (decided 2026-09-14, `open-questions.md`).
- **Toast queueing, a maximum visible count and deduplication** are not planned.
- **A `flash:` keyword that maps `notice`/`alert` automatically** is not planned (§ Non-goals).
- **`window.triggerToast` called before the container connects** (audit TO5) is not in this
  scope. It's unchanged.
