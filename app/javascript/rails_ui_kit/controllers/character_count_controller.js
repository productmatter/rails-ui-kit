import { Controller } from "@hotwired/stimulus"

// The character counter's own bit of chrome-in-the-browser. Field renders the true count first
// (ui-character-counter § Behavior, item 8); this controller keeps it true after that, and
// announces the three thresholds -- ten percent of the limit remaining, over, and back under
// -- into a polite status region the way ui--select announces its result count.
//
//   <div data-controller="ui--field ui--character-count"
//        data-ui--character-count-limit-value="500"
//        data-ui--character-count-format-value="%{count} / %{limit}"
//        data-ui--character-count-remaining-value="{&quot;one&quot;:&quot;…&quot;,&quot;other&quot;:&quot;…&quot;}"
//        data-ui--character-count-over-value="{&quot;one&quot;:&quot;…&quot;,&quot;other&quot;:&quot;…&quot;}"
//        data-ui--character-count-locale-value="en">
//     <textarea data-ui--character-count-target="input" data-action="input->ui--character-count#recount">…</textarea>
//     <p data-slot="field-description"><span data-ui--character-count-target="count">12 / 500</span></p>
//     <div role="status" data-ui--character-count-target="status"></div>
//   </div>
//
// No state of its own (ui-character-counter § Behavior, item 12): everything here is re-derived
// from the textarea's value and the wrapper's own values, on connect, on input, on the form's
// reset, and after a Turbo morph re-renders the field in place -- the one path that keeps this
// element connected without a fresh `connect()` (ui-field-model-binding § Behavior, item 21).
const LOW_REMAINING_RATIO = 0.1

export default class extends Controller {
  static targets = ["input", "count", "status"]

  static values = {
    limit: Number,
    format: { type: String, default: "%{count} / %{limit}" },
    remaining: Object,
    over: Object,
    locale: { type: String, default: "" }
  }

  connect() {
    // null, not a band: the first recount establishes where things stand without announcing it,
    // since nothing has "crossed" into it.
    this.band = null
    // The browser resets the form's fields after the "reset" event finishes, not before, so
    // recounting now would still read the value the user is clearing (the same ordering
    // ui--select's restoreAfterReset works around).
    this.onReset = () => {
      clearTimeout(this.resetTimer)
      this.resetTimer = setTimeout(() => this.recount())
    }
    this.onMorph = (event) => {
      if (event.target === this.element) this.recount()
    }
    this.form?.addEventListener("reset", this.onReset)
    this.element.addEventListener("turbo:morph-element", this.onMorph)
    this.recount()
  }

  disconnect() {
    clearTimeout(this.resetTimer)
    this.form?.removeEventListener("reset", this.onReset)
    this.element.removeEventListener("turbo:morph-element", this.onMorph)
  }

  // Code points (§ Behavior, item 6), matching Ui::FieldComponent#character_count exactly --
  // see the correction there: a line break counts as one, not the two § Behavior, item 7
  // expected, because that is what this stack's Rails actually receives from a Turbo-submitted
  // form, and agreeing with the server is the rule that matters (§ Business rules, rule 2).
  recount() {
    if (!this.hasInputTarget) return

    const text = this.inputTarget.value
    const count = Array.from(text).length
    const over = count > this.limitValue

    this.renderCount(count, over)
    this.updateBand(count, over)
  }

  renderCount(count, over) {
    if (!this.hasCountTarget) return

    this.countTarget.textContent = this.formatValue
      .replace("%{count}", this.formatCount(count))
      .replace("%{limit}", this.formatCount(this.limitValue))

    if (over) {
      this.countTarget.dataset.over = "true"
    } else {
      delete this.countTarget.dataset.over
    }
  }

  // Three moments, never more: entering the low band from normal, entering over from either,
  // and leaving over back to the limit or under. Typing within a band, including low back to
  // normal without ever having gone over, announces nothing (§ Behavior, item 10).
  updateBand(count, over) {
    const remaining = this.limitValue - count
    const lowThreshold = Math.max(1, Math.floor(this.limitValue * LOW_REMAINING_RATIO))
    const band = over ? "over" : remaining <= lowThreshold ? "low" : "normal"
    const previous = this.band
    this.band = band
    if (previous === null || band === previous) return

    if (band === "over") return this.announce(this.overValue, count - this.limitValue)
    if (previous === "over") return this.announce(this.remainingValue, Math.max(remaining, 0))
    if (band === "low") this.announce(this.remainingValue, remaining)
  }

  announce(forms, count) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = this.pluralText(forms, count)
  }

  // Rails' `zero` is an explicit zero form rather than a CLDR category, so it wins at 0 where a
  // locale file defines one; everything else is CLDR's, and an unmatched category falls back to
  // `other`, which every locale has.
  pluralText(forms, count) {
    const category = count === 0 && forms.zero ? "zero" : this.pluralCategory(count)
    const form = forms[category] ?? forms.other ?? ""

    return form.replace("%{count}", this.formatCount(count))
  }

  pluralCategory(count) {
    try {
      return new Intl.PluralRules(this.localeValue || undefined).select(count)
    } catch {
      return "other"
    }
  }

  formatCount(count) {
    try {
      return new Intl.NumberFormat(this.localeValue || undefined).format(count)
    } catch {
      return String(count)
    }
  }

  get form() {
    return this.hasInputTarget ? this.inputTarget.form : null
  }
}
