# Modal and Turbo

`Ui::ModalComponent` opens as soon as it is rendered and takes its own element off the page when
it closes. Everything around that — what puts it on the page, what swaps its contents, what takes
it away — is Turbo's job. This guide is how to do that job, in the order you will build it.

Every sample below is a slice of code the kit's demo app actually runs (`examples/` in the
rails-ui-kit repository, browsable at the docs site's **Modal & Turbo** page), and every claim
here is driven by a browser test (`test/system/modal_turbo_*_test.rb`). Paths in the prose are
written the way a host app writes them. Each sample's code fence records the demo file it is
quoted from (`title="…"`, in the Markdown source), and a test fails if the two ever drift apart.

The resource in the samples is a `Project` with a `name` and a `summary`, listed on a page, edited
in a modal.

## The shape of it

1. The layout holds one container: `<div id="modal" data-turbo-permanent></div>`.
2. A link asks for a Turbo Stream. The response renders `Ui::ModalComponent` into that container.
3. Inside the modal, a Turbo Frame wraps the content, so show ↔ edit and validation errors swap
   the frame and leave the dialog alone.
4. On success the **server** closes the modal, with `turbo_stream.ui_close_modal`, in the same
   response that updates the list row and shows a toast.

Steps 1–4 are the pattern. Everything else in this guide is a detail of one of them.

## 1. The container

Put one container in your layout, next to the kit's other singletons:

```erb title="examples/app/views/layouts/docs.html.erb"
  <%# The modal container: a plain div, not a turbo-frame, so a stream can render any modal into
      it and a form inside one behaves like a form anywhere else. data-turbo-permanent keeps an
      open modal through a morphing page refresh, which would otherwise morph it away. %>
  <div id="modal" data-turbo-permanent></div>
```

A plain `<div>`, not a `<turbo-frame>`. A frame changes how every link and form inside it
behaves; the modal wants a plain element that a stream can write into. (There is a frame-shaped
pattern too — see §10 — but it is for read-only modals only, and it gets a container of its own.)

`data-turbo-permanent` is there for Turbo 8 morphing page refreshes: a refresh morphs `<body>`
from the response, and the response has no modal in it, so an open modal would be morphed away
mid-use. Marking the container permanent makes Turbo skip it.

## 2. Routes, and the trigger

Nothing unusual in the routes — these are the ordinary member routes of a resource:

```ruby title="examples/config/routes.rb"
  # The Modal + Turbo guide's demo resources: real routes, real actions, real 422s. Every route
  # sample in docs/guides/modal-and-turbo.md is one of these.
  resources :projects, path: 'demos/projects', only: %i[show edit update destroy] do
    get :activity, on: :member
  end
  resources :invitations, path: 'demos/invitations', only: %i[new create]
```

The trigger is a plain link with `data-turbo-stream`, which tells Turbo to accept a Turbo Stream
response to a `GET`:

```erb title="examples/app/views/projects/_project.html.erb"
<%# A list row. Its id is what a stream targets to replace or remove it, and the trigger ids are
    what focus returns to -- including when this very row was re-rendered by the same response. %>
<li id="<%= dom_id(project) %>" class="flex items-center justify-between gap-4 border-b border-border px-4 py-3 last:border-b-0">
  <div class="min-w-0">
    <p class="truncate text-sm font-medium text-foreground"><%= project.name %></p>
    <p class="truncate text-xs text-muted-foreground"><%= project.summary %></p>
  </div>
  <div class="flex shrink-0 items-center gap-1">
    <%# data-turbo-stream asks for the Turbo Stream response that opens the modal. %>
    <%= render(Ui::ButtonComponent.new(href: project_path(project), id: dom_id(project, :open), variant: :ghost, size: :sm,
                                       data: { turbo_stream: true })) { "Open" } %>
    <%= render(Ui::ButtonComponent.new(href: edit_project_path(project), id: dom_id(project, :edit), variant: :ghost, size: :sm,
                                       data: { turbo_stream: true })) { "Edit" } %>
    <%# The frame-target pattern: read-only content, rendered into its own turbo-frame. %>
    <%= render(Ui::ButtonComponent.new(href: activity_project_path(project), id: dom_id(project, :activity), variant: :ghost, size: :sm,
                                       data: { turbo_frame: "project_activity_modal" })) { "Activity" } %>
  </div>
</li>
```

Two things in that row matter later:

- **The row is a plain `<li>` with an id.** A stream can target any element id. Do not wrap a
  region in a `<turbo-frame>` just so a stream can reach it.
- **Each trigger has an id.** When the modal closes, focus goes back to the trigger. If the
  response that closed the modal also re-rendered the row the trigger sat in — which is exactly
  what §6 does — the original element is gone, and the id is how the kit finds the control that
  replaced it. A trigger with no id leaves focus where it is.

## 3. Opening the modal

The action is the ordinary one. The template is what makes it a modal:

```ruby title="examples/app/controllers/projects_controller.rb"
  before_action :set_project

  # Opens the modal: show.turbo_stream.erb updates the layout's <div id="modal">. show.html.erb is
  # the same content as a bare frame, which is what an in-modal "Back" link navigates to.
  def show; end

  def edit; end
```

```erb title="examples/app/views/projects/show.turbo_stream.erb"
<%# Opens the modal: the response renders it into the layout's <div id="modal">. Any other region
    this response changed would be updated by further turbo_stream lines in this same template. %>
<%= turbo_stream.update "modal" do %>
  <%= render Ui::ModalComponent.new(track_changes: true, aria: { labelledby: "project_modal_title" }) do %>
    <%= turbo_frame_tag "project_modal_content" do %>
      <%= render "projects/details", project: @project %>
    <% end %>
  <% end %>
<% end %>
```

`turbo_stream.update "modal"` replaces the container's contents, so the same response can open a
modal over an already-open one (§9), and any other region this response changed goes in the same
template, as further `turbo_stream` lines.

**Name every modal.** `aria: { labelledby: "project_modal_title" }` points at a heading the
content renders; `aria: { label: "Command palette" }` names one that has no visible title. The id
you name must exist in *every* state the content frame renders — the read state and the edit
state both carry `id="project_modal_title"` below. An unnamed dialog is announced as nothing.

On open, the kit moves focus into the dialog, locks the page behind it, and remembers the element
to give focus back to. You do not wire any of that.

## 4. The content frame

Inside the modal, wrap the content in a frame:

```erb title="examples/app/views/projects/show.html.erb"
<%# The same content as a bare frame. An in-modal "Cancel" link navigates the content frame here,
    which swaps the frame alone: the dialog is never re-mounted and never re-animates. %>
<%= turbo_frame_tag "project_modal_content" do %>
  <%= render "projects/details", project: @project %>
<% end %>
```

```erb title="examples/app/views/projects/edit.html.erb"
<%# The edit state as a bare frame: what an "Edit" link inside the open modal navigates to, and
    what `render :edit, formats: :html` answers an invalid submission with. %>
<%= turbo_frame_tag "project_modal_content" do %>
  <%= render "projects/form", project: @project %>
<% end %>
```

Now a link inside the modal navigates that frame and nothing else. Show → edit is an ordinary
`link_to`; the dialog is never re-mounted, so it does not re-animate, and focus stays inside it:

```erb title="examples/app/views/projects/_form.html.erb"
<div class="p-6 sm:p-8">
  <h2 id="project_modal_title" class="text-base font-semibold text-foreground">Edit project</h2>

  <%# ui--form-change is what makes track_changes: true mean anything: it tells the modal when
      the form is dirty, so closing it asks first. %>
  <%= form_with model: project, class: "mt-5 grid gap-4", data: { controller: "ui--form-change" } do |form| %>
    <%= render Ui::FieldComponent.new(model: project, attribute: :name) %>
    <%= render Ui::FieldComponent.new(model: project, attribute: :summary) %>

    <div class="mt-2 flex items-center justify-end gap-2">
      <%# Back to the read state: a plain link, so it swaps the content frame and nothing else. %>
      <%= render(Ui::ButtonComponent.new(href: project_path(project), variant: :outline, size: :sm)) { "Cancel" } %>
      <%= render(Ui::ButtonComponent.new(type: "submit", size: :sm)) { "Save" } %>
    </div>
  <% end %>
</div>
```

The frame's id has to be unique **on the whole page**, not just inside the modal. If the page
behind the modal has a frame with the same id, a link inside the modal resolves to that one and
your modal's content never changes.

Opening straight into the edit state is the same stream response with a different partial:

```erb title="examples/app/views/projects/edit.turbo_stream.erb"
<%# Opening straight into the edit state, from the list's Edit link. %>
<%= turbo_stream.update "modal" do %>
  <%= render Ui::ModalComponent.new(track_changes: true, aria: { labelledby: "project_modal_title" }) do %>
    <%= turbo_frame_tag "project_modal_content" do %>
      <%= render "projects/form", project: @project %>
    <% end %>
  <% end %>
<% end %>
```

## 5. Validation errors: always `422`

Turbo rejects a `200` HTML response to a form submission — it expects a redirect or an error
status — so a re-rendered invalid form must answer `422 Unprocessable Entity`. In a modal there
is a second reason, and it is the one that bites: `ui--modal#closeOnSuccess` (§7) closes on any
`2xx`. A `200` re-render of an invalid form would close the modal on a failed save.

```ruby title="examples/app/controllers/projects_controller.rb"
  def update
    if @project.update(project_params)
      flash.now[:notice] = "#{@project.name} saved."
      # update.turbo_stream.erb: close the modal, and update every region this change touched.
    else
      # formats: :html, because a form submission asks for Turbo Stream first and `render :edit`
      # would otherwise pick edit.turbo_stream.erb -- the template that *opens* the modal -- and
      # re-mount it over itself. 422, because Turbo rejects a 200 HTML response to a form.
      render :edit, formats: :html, status: :unprocessable_entity
    end
  end
```

`formats: :html` is not decoration. A form submission lists Turbo Stream **first** in its
`Accept` header, so a bare `render :edit` finds `edit.turbo_stream.erb` — the template that
*opens* the modal — and re-mounts a second modal over the one already open. Ask for the HTML
template explicitly and the error re-renders inside the content frame, where it belongs: the
field is marked `aria-invalid`, its message is what describes it, and the modal does not move.

Prefer validations the browser cannot pre-empt when you are demonstrating this to yourself: a
`required` field never reaches the server at all.

## 6. Success: the server closes the modal

The server is the side that knows the save succeeded, so the server closes the modal — in the
same response that updates everything else the change touched:

```erb title="examples/app/views/projects/update.turbo_stream.erb"
<%# The success response, and the whole close: the server knows the save went through, so it
    closes the modal with its exit animation and updates every region the change touched.
    The row is a plain <li id="project_1">, not a turbo-frame -- a stream targets any id. %>
<%= turbo_stream.ui_close_modal %>
<%= turbo_stream.replace @project %>
<%= turbo_stream.ui_toast(type: :notice, description: flash[:notice]) %>
```

`turbo_stream.ui_close_modal` is the kit's own Turbo Stream action:

- It closes the kit modal inside the target container **with its exit animation**, and leaves the
  container in place for the next modal.
- It targets `"modal"` by default; pass another id — `turbo_stream.ui_close_modal "drawer"` —
  where your container is called something else.
- It does nothing when no modal is open, so a response may safely send it next to a form wired to
  `closeOnSuccess`.
- It skips the unsaved-changes prompt (§8). The change the prompt protects has just been accepted.

`turbo_stream.ui_toast` is the kit's toast, sent the same way. It appends to the stack
`Ui::ToastContainerComponent` renders, so render that container once in your layout, as the install
generator tells you to — without it there is nothing for the toast to land in. It is Turbo's own
`append`, and the payload is checked in Ruby before it is sent: a `description:` like this one, or
a `title:`, `actions:` and the rest (see the Toast page).

Do not close a modal with `turbo_stream.remove` or an empty `turbo_stream.update`. The kit cleans
up either way — scroll lock released, focus restored — but the modal vanishes in a frame instead
of animating out.

Focus lands back on the trigger, including here, where the same response replaced the row the
trigger was in: the kit remembers the trigger's id and gives focus to whatever now carries it.

## 7. When the success response has nothing to render

Some modals change nothing on the page behind them. There is no stream to send, so there is
nothing to close the modal — that is what `ui--modal#closeOnSuccess` is for:

```erb title="examples/app/views/invitations/_form.html.erb"
  <%# The convenience close: Turbo reports the outcome of the submission, and a 2xx is the server
      having accepted it. It is safe only because the invalid case answers 422, never a 2xx. %>
  <%= form_with model: invitation, class: "mt-5 grid gap-4",
        data: { action: "turbo:submit-end->ui--modal#closeOnSuccess" } do |form| %>
    <%= render Ui::FieldComponent.new(model: invitation, attribute: :email) do |field| %>
      <% field.with_control(Ui::InputComponent, type: "email") %>
    <% end %>

    <div class="mt-2 flex items-center justify-end gap-2">
      <%= render(Ui::ButtonComponent.new(variant: :outline, size: :sm, data: { action: "click->ui--modal#close" })) { "Cancel" } %>
      <%= render(Ui::ButtonComponent.new(type: "submit", size: :sm)) { "Send invite" } %>
    </div>
  <% end %>
```

```ruby title="examples/app/controllers/invitations_controller.rb"
  def create
    @invitation = Invitation.new(invitation_params)

    if @invitation.valid?
      # Nothing on the page behind the modal changed, so there is nothing to render. The form's
      # turbo:submit-end->ui--modal#closeOnSuccess closes the modal on this 204.
      head :no_content
    else
      render :new, formats: :html, status: :unprocessable_entity
    end
  end
```

It closes through the same animated close as everything else, and only on Turbo's own
`event.detail.success`, which is true for any `2xx`. **That is safe only because every invalid
submission answers `422`** (§5). If any path in your controller answers an invalid form with a
`2xx`, this action will close the modal on a failure — the exact defect this guide exists to
prevent.

Reach for the stream action first. `closeOnSuccess` is for the case where the response carries
nothing at all.

## 8. Closing without saving

A close button is one action on any element inside the modal:

```erb title="examples/app/views/projects/_details.html.erb"
    <%= render(Ui::ButtonComponent.new(variant: :outline, size: :sm, data: { action: "click->ui--modal#close" })) { "Close" } %>
```

Escape and a click on the backdrop do the same thing, with no server request. All three release
the scroll lock and return focus to the trigger.

With `track_changes: true` on the modal (§3) and `ui--form-change` on the form (§4), a close
gesture over a dirty form asks first, through the kit's ConfirmDialog. The server's own close
(§6) never asks.

A destructive action asks too — `data: { turbo_confirm: ... }` reaches the kit's ConfirmDialog,
which opens above the modal:

```erb title="examples/app/views/projects/_details.html.erb"
    <%# Destructive, so it asks first -- through the kit's ConfirmDialog, which opens above the
        modal and leaves it open when the answer is no. %>
    <%= form_with url: project_path(project), method: :delete, data: { turbo_confirm: "Delete #{project.name}? This cannot be undone." } do %>
      <%= render(Ui::ButtonComponent.new(type: "submit", variant: :ghost, size: :sm, class: "text-destructive hover:bg-destructive/10")) { "Delete" } %>
    <% end %>
```

```erb title="examples/app/views/projects/destroy.turbo_stream.erb"
<%= turbo_stream.ui_close_modal %>
<%= turbo_stream.remove @project %>
<%= turbo_stream.ui_toast(type: :notice, description: flash[:notice]) %>
```

Cancelling the confirmation leaves the modal open with focus back inside it. Confirming closes
the modal and removes the row — and because the trigger went with the row, focus is left where it
is rather than thrown to the top of the page.

## 9. Replacing an open modal

A stream that updates the container while a modal is open replaces it. One dialog before, one
dialog after, the page locked throughout, and closing the second modal returns focus to the
element that opened the first. A link inside the modal is all it takes:

```erb title="examples/app/views/projects/_details.html.erb"
    <%# A stream link inside an open modal: its response updates "modal", which replaces this
        modal with the next one. %>
    <%= render(Ui::ButtonComponent.new(href: new_invitation_path, variant: :ghost, size: :sm, data: { turbo_stream: true })) { "Invite a teammate" } %>
```

## 10. The other pattern: a frame target, for read-only modals

A link with `data-turbo-frame` pointed at a `<turbo-frame>` of its own also opens a modal, and
for read-only content — a preview, an activity list, a help panel — it is a fine, smaller
pattern:

```erb title="examples/app/views/projects/_project.html.erb"
    <%# The frame-target pattern: read-only content, rendered into its own turbo-frame. %>
    <%= render(Ui::ButtonComponent.new(href: activity_project_path(project), id: dom_id(project, :activity), variant: :ghost, size: :sm,
                                       data: { turbo_frame: "project_activity_modal" })) { "Activity" } %>
```

```erb title="examples/app/views/projects/activity.html.erb"
<%# The frame-target pattern, and the only place the guide shows it: read-only content, rendered
    into a turbo-frame of its own. Never a form -- a redirect after a successful submission
    renders "Content missing" inside a frame. %>
<%= turbo_frame_tag "project_activity_modal" do %>
  <%= render Ui::ModalComponent.new(position: :right, aria: { labelledby: "project_activity_title" }) do %>
```

**Never put a form in it.** The redirect a successful submission answers with renders "Content
missing" inside the frame, because the redirect target has no frame of that id. Give the frame
pattern its own container id, too: the layout's shared `<div id="modal">` belongs to the stream
pattern.

## Gotchas

**A `200` HTML response to a form submission is rejected by Turbo.** Answer `422` on failure and
a stream, a redirect or `204` on success. See §5.

**`render :edit` picks the Turbo Stream template.** A form submission asks for Turbo Stream
first, so the template that opens your modal wins over the one that re-renders its contents.
`render :edit, formats: :html`. See §5.

**Don't wrap a region in a `<turbo-frame>` just to stream into it.** `turbo_stream.replace
@project` targets `id="project_1"`; any element id works. A frame also changes how every link and
form inside that region behaves, which is a large price for an id you already had. See §2.

**Content-frame ids must be unique on the page.** A frame inside the modal whose id matches a
frame on the page behind it resolves to the wrong one, and the modal appears not to respond.

**Name the modal, in every state.** `aria: { labelledby: }` must point at an id that the content
frame renders in each state it can be in, or the dialog loses its name halfway through a flow.

**The Back button never restores a modal.** The kit removes an open modal before Turbo caches the
page, which is what stops Back from restoring a stuck, un-closable modal. Nothing to do; be aware
that Back closes rather than reopens.

**Don't put `data-turbo-action="advance"` on a trigger that opens a modal.** The advance visit
caches a page snapshot the moment the response lands, and the cache teardown above removes the
modal that just opened — you get a flash, not a deep link. Deep-linkable modals need a different
pattern than this guide's.

**Turbo 8 morphing refreshes wipe an open modal** unless its container is `data-turbo-permanent`
(§1). This is what a page that opts into morphing looks like:

```erb title="examples/app/views/docs/modal_turbo.html.erb"
<%# The morphing-refresh demo: this page opts into morph refreshes, which is what makes
    data-turbo-permanent on the layout's modal container matter. %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

## Reference

`Ui::ModalComponent` — the options this guide uses:

| Option | Default | What it does |
|---|---|---|
| `aria:` | `{}` | Attributes for the `<dialog>`. `{ labelledby: "id" }` or `{ label: "…" }` names it. Always pass one. |
| `track_changes:` | `false` | Ask before closing while a form inside is dirty. Needs `ui--form-change` on the form. |
| `close_on_backdrop:` | `true` | Whether a backdrop click closes it. Escape and the close button are unaffected. |
| `position:` | `:center` | `:center`, `:right`, `:left`, `:top`, `:bottom`, `:top_full`, `:bottom_full`, `:full_screen`. |

Actions and helpers:

| Name | Where | What it does |
|---|---|---|
| `ui--modal#close` | `data-action` on a control inside the modal | Closes it, asking first if the form is dirty. |
| `ui--modal#closeOnSuccess` | `data-action="turbo:submit-end->…"` on a form | Closes it when the submission succeeded (`2xx`). |
| `turbo_stream.ui_close_modal(target = "modal")` | a `*.turbo_stream.erb` response | Closes the kit modal in that container, with its exit animation. |

## Checklist

- [ ] The layout has one `<div id="modal" data-turbo-permanent></div>`.
- [ ] The trigger is a link with `data-turbo-stream`, and it has an id.
- [ ] The response is `turbo_stream.update "modal"` rendering `Ui::ModalComponent`.
- [ ] The modal is named with `aria:`, and that id exists in every state.
- [ ] The content is wrapped in a `turbo_frame_tag` with a page-unique id.
- [ ] Every invalid submission answers `422`, in every format.
- [ ] Invalid re-renders use `formats: :html`.
- [ ] Success sends `turbo_stream.ui_close_modal` plus the regions that changed.
- [ ] A form whose success renders nothing uses `turbo:submit-end->ui--modal#closeOnSuccess`.
- [ ] No form lives inside the frame-target pattern.
