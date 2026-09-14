import ModalController from "rails_ui_kit/controllers/modal_controller"
import DropdownController from "rails_ui_kit/controllers/dropdown_controller"
import DialogController from "rails_ui_kit/controllers/dialog_controller"
import ToastController from "rails_ui_kit/controllers/toast_controller"
import ToastContainerController from "rails_ui_kit/controllers/toast_container_controller"
import FormChangeController from "rails_ui_kit/controllers/form_change_controller"
import TurboConfirmController from "rails_ui_kit/controllers/turbo_confirm_controller"
import TurboDisableWithController from "rails_ui_kit/controllers/turbo_disable_with_controller"
import DarkModeController from "rails_ui_kit/controllers/dark_mode_controller"
import TooltipController from "rails_ui_kit/controllers/tooltip_controller"
import PopoverController from "rails_ui_kit/controllers/popover_controller"
import AnchorController from "rails_ui_kit/controllers/anchor_controller"
import RovingFocusController from "rails_ui_kit/controllers/roving_focus_controller"
import PresenceController from "rails_ui_kit/controllers/presence_controller"
import OverlayController from "rails_ui_kit/controllers/overlay_controller"
import SelectController from "rails_ui_kit/controllers/select_controller"
import FieldController from "rails_ui_kit/controllers/field_controller"
import ChoicesController from "rails_ui_kit/controllers/choices_controller"

export {
  ModalController,
  DropdownController,
  DialogController,
  ToastController,
  ToastContainerController,
  FormChangeController,
  TurboConfirmController,
  TurboDisableWithController,
  DarkModeController,
  TooltipController,
  PopoverController,
  AnchorController,
  RovingFocusController,
  PresenceController,
  OverlayController,
  SelectController,
  FieldController,
  ChoicesController
}

const MODAL_SELECTOR = '[data-controller~="ui--modal"]'

// turbo_stream.ui_close_modal -- the kit's one custom Turbo Stream action, namespaced the way
// its Stimulus identifiers and its Ruby namespace are, so it can't collide with an action a host
// app registers. It closes the kit modal inside the target container with its exit animation and
// leaves the container in place for the next modal; with no modal there it does nothing, so a
// response may safely send it alongside a form wired to ui--modal#closeOnSuccess.
//
// Turbo's own registry is reached through window.Turbo, which Turbo sets as it starts. Importing
// @hotwired/turbo here instead would make every importmap host pin a module they don't otherwise
// name (§ Assumptions of ui-modal-turbo: no new pin for host apps).
export function registerStreamActions(application, streamActions = window.Turbo?.StreamActions) {
  if (!streamActions) {
    console.error("rails-ui-kit: Turbo is not loaded, so turbo_stream.ui_close_modal will not run")
    return
  }

  streamActions.ui_close_modal = function () {
    this.targetElements.forEach((container) => {
      modalsInside(container).forEach((element) => {
        application.getControllerForElementAndIdentifier(element, "ui--modal")?.closeFromServer()
      })
    })
  }
}

function modalsInside(container) {
  const nested = Array.from(container.querySelectorAll(MODAL_SELECTOR))

  return container.matches(MODAL_SELECTOR) ? [container, ...nested] : nested
}

export function registerControllers(application) {
  registerStreamActions(application)

  application.register("ui--modal", ModalController)
  application.register("ui--dropdown", DropdownController)
  application.register("ui--dialog", DialogController)
  application.register("ui--toast", ToastController)
  application.register("ui--toast-container", ToastContainerController)
  application.register("ui--form-change", FormChangeController)
  application.register("ui--turbo-confirm", TurboConfirmController)
  application.register("ui--turbo-disable-with", TurboDisableWithController)
  application.register("ui--dark-mode", DarkModeController)
  application.register("ui--tooltip", TooltipController)
  application.register("ui--popover", PopoverController)
  application.register("ui--anchor", AnchorController)
  application.register("ui--roving-focus", RovingFocusController)
  application.register("ui--presence", PresenceController)
  application.register("ui--overlay", OverlayController)
  application.register("ui--select", SelectController)
  application.register("ui--field", FieldController)
  application.register("ui--choices", ChoicesController)
}
