import ModalController from "rails_ui_kit/controllers/modal_controller"
import DropdownController from "rails_ui_kit/controllers/dropdown_controller"
import DialogController from "rails_ui_kit/controllers/dialog_controller"
import ToastController from "rails_ui_kit/controllers/toast_controller"
import ToastContainerController from "rails_ui_kit/controllers/toast_container_controller"
import FormChangeController from "rails_ui_kit/controllers/form_change_controller"
import TurboConfirmController from "rails_ui_kit/controllers/turbo_confirm_controller"
import TurboDisableWithController from "rails_ui_kit/controllers/turbo_disable_with_controller"
import DarkModeController from "rails_ui_kit/controllers/dark_mode_controller"

export {
  ModalController,
  DropdownController,
  DialogController,
  ToastController,
  ToastContainerController,
  FormChangeController,
  TurboConfirmController,
  TurboDisableWithController,
  DarkModeController
}

export function registerControllers(application) {
  application.register("ui--modal", ModalController)
  application.register("ui--dropdown", DropdownController)
  application.register("ui--dialog", DialogController)
  application.register("ui--toast", ToastController)
  application.register("ui--toast-container", ToastContainerController)
  application.register("ui--form-change", FormChangeController)
  application.register("ui--turbo-confirm", TurboConfirmController)
  application.register("ui--turbo-disable-with", TurboDisableWithController)
  application.register("ui--dark-mode", DarkModeController)
}
