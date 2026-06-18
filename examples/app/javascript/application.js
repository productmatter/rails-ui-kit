import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "rails-ui-kit"

const application = Application.start()
registerControllers(application)
