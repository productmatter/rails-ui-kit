import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "rails-ui-kit"

const application = Application.start()
registerControllers(application)

// The Stimulus handbook's convention for reaching the application from the console. The browser
// lane's kit invariants use it to prove every ui--* controller on a page is connected
// (docs/specs/ui-stress-page § Behavior, item 10).
window.Stimulus = application
