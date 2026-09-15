# Building a form

A Rails form built from the kit is `form_with` plus one `Ui::FieldComponent` per attribute. Give a
Field the record and the attribute, and it derives everything a hand-written field gets wrong in
at least one place: the name, the id, the label, the value, the errors and whether the field is
required. This guide builds one form, in the order you will write it, including the shapes Rails
makes awkward — an enum, a `belongs_to`, a `has_many` edited as ids, and nested attributes.

Every sample below is a slice of code the kit's demo app actually runs (`examples/` in the
rails-ui-kit repository, browsable at the docs site's **Building a form** page), driven by
`test/system/forms_guide_test.rb`. Each sample's code fence records the file it is quoted from
(`title="…"`, in the Markdown source), and a test fails if the two drift apart.

The record is a `Member` with a `name`, an `enum :status`, `belongs_to :team`,
`has_many :roles`, and `has_one :address` with `accepts_nested_attributes_for :address`. The demo
app has no database, so its `Member` is an ActiveModel object that behaves the way that
ActiveRecord model would; the form and the controller are the ones you would write against the
real thing.

## The shape of it

1. An ordinary resource: `edit`, and an `update` that redirects on success and re-renders with
   `422` on failure.
2. `form_with model:` for the form, and a model-bound Field for each attribute inside it.
3. The control is the Field's business: Input by default, Select for an enum or an association,
   Choices for a group.
4. Two attributes need one extra word, because Rails keys their errors or names differently from
   the field: an association's errors, and a nested record's name.

## 1. The route and the controller

Nothing about the kit changes the controller:

```ruby title="examples/config/routes.rb"
  # docs/guides/forms.md's demo resource: a real edit and update, with a real 422.
  resources :members, path: 'demos/members', only: %i[edit update]
```

```ruby title="examples/app/controllers/members_controller.rb"
  def edit; end

  def update
    if @member.update(member_params)
      redirect_to edit_member_path(@member), notice: "#{@member.name} saved.", status: :see_other
    else
      # 422, or Turbo won't render the response: it rejects a 200 answer to a form submission.
      render :edit, status: :unprocessable_entity
    end
  end
```

The `422` is not optional. Turbo drives the submission, and it refuses to render a `200` HTML
response to a form: it expects a redirect or an error status. The re-rendered form is where every
Field below shows its errors, so an invalid save that answers `200` shows nothing at all.

## 2. From `form_with` to a bound Field

```erb title="examples/app/views/members/_form.html.erb"
<%= form_with model: member, class: "grid max-w-lg gap-6" do |form| %>
  <%# The record supplies the name, id, label, value, errors and required. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :name) %>
```

That one line renders what `form.label`, `form.text_field` and an error message would, wired
together: `name="member[name]"` and `id="member_name"`, exactly as `form_with` names them; the
label from `helpers.label.member.name` or `human_attribute_name`, so your locale files translate
it; the record's value; `member.errors[:name]` as the error, with `aria-invalid` and
`aria-describedby` pointing at it; and `required`, because `Member` validates the presence of
`name` unconditionally. A conditional validator (`if:`, `on:`) doesn't mark the field required —
a control wrongly marked required blocks a save the model would accept.

Anything you state wins over what the record implies, one value at a time: `required: false`, a
`with_label` block, `errors:` or `name:`. The rest is still derived.

## 3. A Select from an enum

```erb title="examples/app/views/members/_form.html.erb"
  <%# An enum: the options come from Member.statuses, their labels from human_attribute_name. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :status) do |field| %>
    <% field.with_control(Ui::SelectComponent, model: Member, enum: :status) %>
  <% end %>
```

`model:` and `enum:` read the enum's mapping in declaration order and label each value through
`human_attribute_name("status.invited")`, so `activerecord.attributes.member/status.invited` in
your locale files is the label, falling back to "Invited". The value submitted is the enum key,
which is what the enum writer takes. The Field gives the Select the record's status as `selected:`.

The Select is a real `<select>` that submits, with a combobox over it; with JavaScript off, the
native select is what the user gets.

## 4. A `belongs_to`

```erb title="examples/app/views/members/_form.html.erb"
  <%# belongs_to validates the association, so its error is on :team, not the :team_id this edits. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :team_id,
                                    errors: member.errors[:team_id] + member.errors[:team]) do |field| %>
    <% field.with_control(Ui::SelectComponent, collection: Team.all, value_method: :id, text_method: :name,
                          include_blank: "No team") %>
  <% end %>
```

`belongs_to :team` puts its "must exist" error on `:team`. The field edits `:team_id`, and a Field
reads the errors for its own attribute — the same key Rails' own `form.select :team_id` reads —
so without `errors:` a member with no team fails to save and the form shows no reason why. Name
both keys.

Nothing validates `team_id` itself, so the Field is not marked required. If a team must be
chosen before the form can submit, say `required: true`.

## 5. A `has_many`, as Choices

```erb title="examples/app/views/members/_form.html.erb"
  <%# has_many is validated as :roles and edited as :role_ids, so the Field is told which errors are its own. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :role_ids, required: true,
                                    errors: member.errors[:roles]) do |field| %>
    <% field.with_label { "Roles" } %>
    <% field.with_control(Ui::ChoicesComponent, multiple: true, collection: Role.all,
                          value_method: :id, text_method: :name, disabled_values: Role.locked_ids) %>
    <% field.with_description { "Owner is managed by billing and can't be changed here." } %>
  <% end %>
```

A checkbox group renders what `collection_check_boxes` renders: `member[role_ids][]` per box, and
a hidden empty entry first, so unchecking every box clears the association instead of silently
keeping the old roles. A model validates the association (`:roles`) and the form edits the ids
(`:role_ids`), so this is the same one extra word as §4. The label is stated because
`"role_ids".humanize` is "Role ids".

`required: true` on a checkbox group means "at least one": the browser has no such constraint, so
the kit's `ui--choices` controller supplies it, and with JavaScript off the server's validation is
what catches it.

### A locked checkbox is not authorization

`disabled_values:` renders a choice the user can't change. A disabled checkbox never submits, so
Rails' own markup would delete a locked role on every save; the kit carries a checked locked value
in a hidden input instead, and the save keeps what the form showed.

A hidden input can be removed or edited in the browser, and a disabled checkbox re-enabled. The
server still decides what a user may change, so filter or merge locked values in the controller:

```ruby title="examples/app/controllers/members_controller.rb"
  def member_params
    params.require(:member)
          .permit(:name, :status, :team_id, role_ids: [], address_attributes: [:city])
          .tap { |permitted| permitted[:role_ids] = role_ids_this_user_may_set(permitted[:role_ids]) }
  end

  # A locked choice is carried by a hidden input, and a hidden input can be edited in the browser.
  # So the server decides: whatever arrived for a locked role is dropped, and the member keeps the
  # locked roles they already had.
  def role_ids_this_user_may_set(submitted)
    locked = Role.locked_ids
    (Array(submitted).compact_blank.map(&:to_i) - locked) | (@member.role_ids & locked)
  end
```

## 6. Nested attributes

```erb title="examples/app/views/members/_form.html.erb"
  <%# Nested attributes: the nested record is the model, and fields_for supplies its full name. %>
  <%= form.fields_for :address do |address_form| %>
    <%= render Ui::FieldComponent.new(model: address_form.object, attribute: :city,
                                      name: address_form.field_name(:city)) %>
  <% end %>
```

A Field doesn't work out nested names. Give it the nested record as `model:`, so the errors, the
label, the value and required come from the address, and the full name as `name:` —
`member[address_attributes][city]` here. `fields_for` knows that name, including the index of a
`has_many` (`member[addresses_attributes][0][city]`), so ask it rather than writing the string.
The id derives from the name, and matches what `fields_for` would render.

## 7. The 422 re-render

`render :edit, status: :unprocessable_entity` (§1) renders the same form from the same record,
now carrying its errors:

```erb title="examples/app/views/members/edit.html.erb"
<%= render "form", member: @member %>
```

Each Field shows its own message, marks its control `aria-invalid`, and points `aria-describedby`
at the message, so a screen reader reads the error with the field. What the user typed or chose
comes back as the value, because the record holds the submitted attributes.

Test a 422 with a failure the browser cannot pre-empt: a `required` field never reaches the
server. In the demo, choosing "No team" is that failure.

## 8. The submitting state

```erb title="examples/app/views/members/_form.html.erb"
  <div>
    <%= render(Ui::ButtonComponent.new(type: "submit", data: { turbo_disable_with: "Saving…",
                                                               turbo_disable_style: "spinner" })) { "Save" } %>
  </div>
```

`data-turbo-disable-with` is read by the `ui--turbo-disable-with` controller in your layout. While
the request runs, the button is disabled, keeps its height, shows the text with a spinner
(`turbo_disable_style: "pulse"` fades it instead) and announces it to screen readers; it comes back
when Turbo reports the response. Pass the text through `t(".saving")` like any other content, or
leave it out and the layout's `<meta name="turbo-disable-with-default">` — or the kit's own
`rails_ui_kit.turbo_disable_with.processing` — is used.

## 9. Testing it

An enhanced Select lays its native `<select>` over the combobox at `opacity: 0`, so Capybara's
`select "Invited", from: "Status"` no longer picks what a user would. The kit ships a helper that
drives the widget the way a person does, and falls back to the native select where it was never
enhanced:

```ruby title="test/system/forms_guide_test.rb"
require 'application_system_test_case'
require 'rails_ui_kit/test_helpers'
```

```ruby title="test/system/forms_guide_test.rb"
class FormsGuideTest < ApplicationSystemTestCase
  include RailsUiKit::TestHelpers
```

```ruby title="test/system/forms_guide_test.rb"
  test 'a member with no team comes back 422, with the error on the field that edits it' do
    ui_select 'No team', from: 'Team'
    fill_in 'Name', with: 'Sam Okafor'
    click_on 'Save'

    assert_selector '#member_team_id-error', text: 'must exist'
    assert_field 'Name', with: 'Sam Okafor'
  end
```

`from:` takes the Field's label, the name the form posts, or the control's id. Checkboxes, radios
and inputs are native, so `check`, `choose` and `fill_in` work on them unchanged.

## Checklist

- [ ] `update` answers `422` on failure, and redirects with `303` on success.
- [ ] Every field is `Ui::FieldComponent.new(model:, attribute:)`; a label, `errors:` or
      `required:` is stated only where the record can't say it.
- [ ] An association's field names the association's errors: `errors[:team]`, `errors[:roles]`.
- [ ] A nested field passes the nested record as `model:` and `fields_for`'s `field_name` as `name:`.
- [ ] Every value locked with `disabled_values:` is enforced again in the controller.
- [ ] The submit button carries `data-turbo-disable-with`, and the layout renders
      `ui--turbo-disable-with`.
- [ ] System tests choose from a Select with `ui_select`.
