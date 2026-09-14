import { Controller } from "@hotwired/stimulus"

const SPINNER_MARKUP = `
  <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true">
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
  </svg>
`

export default class extends Controller {
  connect() {
    this.boundHandlers = {
      submitStart: this.handleSubmitStart.bind(this),
      submitEnd: this.handleSubmitEnd.bind(this),
      reset: this.handleReset.bind(this),
      submit: this.handleStandardSubmit.bind(this),
      beforeCache: this.handleBeforeCache.bind(this)
    }

    this.elementStates = new WeakMap()
    this.disabledElements = new Set()

    document.addEventListener('turbo:submit-start', this.boundHandlers.submitStart)
    document.addEventListener('turbo:submit-end', this.boundHandlers.submitEnd)
    document.addEventListener('submit', this.boundHandlers.submit)
    document.addEventListener('reset', this.boundHandlers.reset)
    document.addEventListener('turbo:before-cache', this.boundHandlers.beforeCache)
  }

  disconnect() {
    document.removeEventListener('turbo:submit-start', this.boundHandlers.submitStart)
    document.removeEventListener('turbo:submit-end', this.boundHandlers.submitEnd)
    document.removeEventListener('submit', this.boundHandlers.submit)
    document.removeEventListener('reset', this.boundHandlers.reset)
    document.removeEventListener('turbo:before-cache', this.boundHandlers.beforeCache)
  }

  // Turbo snapshots the page into its cache before navigating away. If we
  // leave disabled/"Saving..." elements in that snapshot, pressing Back
  // restores the stuck state until the user does a full reload. Restore
  // every element we've disabled so the cached snapshot matches the
  // pre-submit page.
  handleBeforeCache() {
    this.disabledElements.forEach(element => this.enableElement(element))
  }

  handleSubmitStart(event) {
    const form = event.target.closest('form') || event.target
    if (!form) return

    const submitter = event.detail?.formSubmission?.submitter
    const elements = form.querySelectorAll('[data-turbo-disable-with]')
    elements.forEach(element => this.disableElement(element, element === submitter))
  }

  handleSubmitEnd(event) {
    const form = event.target.closest('form') || event.target
    if (!form) return

    const elements = form.querySelectorAll('[data-turbo-disable-with]')
    elements.forEach(element => this.enableElement(element))
  }

  handleReset(event) {
    const form = event.target
    const elements = form.querySelectorAll('[data-turbo-disable-with]')
    elements.forEach(element => this.enableElement(element))
  }

  handleStandardSubmit(event) {
    const form = event.target
    if (!form || form.tagName !== 'FORM') return

    const isTurboForm = form.getAttribute('data-turbo') !== 'false'
    if (isTurboForm) return

    const elements = form.querySelectorAll('[data-turbo-disable-with]')
    elements.forEach(element => this.disableElement(element))
  }

  disableElement(element, isSubmitter = false) {
    const isInput = element.tagName.toLowerCase() === 'input'
    const originalText = isInput ? element.value : element.innerHTML
    // Turbo disables the submitter itself before dispatching
    // turbo:submit-start, so element.disabled already reads true there --
    // but a disabled button can't have submitted the form in the first
    // place, so we know the submitter's real original state was false.
    // Every other element wasn't touched, so its live `disabled` is
    // trustworthy (including one app JS disabled for its own reasons).
    const originalDisabled = isSubmitter ? false : element.disabled
    const originalAriaLabel = element.getAttribute('aria-label')
    const disableText = element.dataset.turboDisableWith || this.getDefaultText()
    const style = element.dataset.turboDisableStyle || 'text'

    const originalHeight = !isInput ? element.offsetHeight : null

    this.elementStates.set(element, {
      originalText,
      originalDisabled,
      originalAriaLabel,
      originalHeight,
      isInput,
      style
    })
    this.disabledElements.add(element)

    element.disabled = true
    element.setAttribute('aria-busy', 'true')
    element.classList.add('submitting', 'pointer-events-none', 'opacity-75')

    if (isInput) {
      element.value = disableText
      element.setAttribute('aria-label', disableText)
    } else {
      if (originalHeight) {
        element.style.height = `${originalHeight}px`
      }

      switch (style) {
        case 'spinner':
        case 'pulse':
          element.replaceChildren(this.indicator(disableText, style))
          break
        default:
          element.textContent = disableText
          element.setAttribute('aria-label', disableText)
      }
    }

    this.announceToScreenReader(disableText)
  }

  enableElement(element) {
    const state = this.elementStates.get(element)
    if (!state) return

    this.disabledElements.delete(element)
    element.disabled = state.originalDisabled
    element.removeAttribute('aria-busy')
    element.classList.remove('submitting', 'pointer-events-none', 'opacity-75')

    if (state.originalHeight && !state.isInput) {
      element.style.height = ''
    }

    if (state.originalAriaLabel) {
      element.setAttribute('aria-label', state.originalAriaLabel)
    } else {
      element.removeAttribute('aria-label')
    }

    if (state.isInput) {
      element.value = state.originalText
    } else {
      element.innerHTML = state.originalText
    }

    this.elementStates.delete(element)
  }

  getDefaultText() {
    const metaTag = document.querySelector('meta[name="turbo-disable-with-default"]')
    return metaTag?.content || 'Processing...'
  }

  announceToScreenReader(message) {
    let liveRegion = document.getElementById('rails-ui-kit-announcer')

    if (!liveRegion) {
      liveRegion = document.createElement('div')
      liveRegion.id = 'rails-ui-kit-announcer'
      liveRegion.setAttribute('role', 'status')
      liveRegion.setAttribute('aria-live', 'polite')
      liveRegion.setAttribute('aria-atomic', 'true')
      liveRegion.className = 'sr-only'
      document.body.appendChild(liveRegion)
    }

    liveRegion.textContent = ''
    setTimeout(() => {
      liveRegion.textContent = message
    }, 100)
  }

  // The disable text is chrome: it comes from a translation or from the call site, so it can
  // hold a quote, an ampersand or an angle bracket. Built as nodes -- never interpolated into
  // markup -- so a quote can't break out of aria-label and a tag can't become an element.
  indicator(text, style) {
    const wrapper = document.createElement('span')
    wrapper.setAttribute('role', 'status')
    wrapper.setAttribute('aria-label', text)

    if (style === 'spinner') {
      wrapper.className = 'flex items-center justify-center gap-2 w-full h-full'
      wrapper.appendChild(this.spinnerSVG())

      // Hidden from the accessibility tree because the wrapper's aria-label already names it.
      const label = document.createElement('span')
      label.setAttribute('aria-hidden', 'true')
      label.textContent = text
      wrapper.appendChild(label)
    } else {
      wrapper.className = 'flex items-center justify-center w-full h-full animate-pulse'
      wrapper.textContent = text
    }

    return wrapper
  }

  // Static markup with nothing interpolated into it, parsed once into a node.
  spinnerSVG() {
    const template = document.createElement('template')
    template.innerHTML = SPINNER_MARKUP
    return template.content.firstElementChild
  }
}
