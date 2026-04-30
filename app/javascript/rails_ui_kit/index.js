import ModalController from "./controllers/modal_controller"
import DropdownController from "./controllers/dropdown_controller"
import DialogController from "./controllers/dialog_controller"
import ToastController from "./controllers/toast_controller"
import ToastContainerController from "./controllers/toast_container_controller"
import FormChangeController from "./controllers/form_change_controller"
import TurboConfirmController from "./controllers/turbo_confirm_controller"
import TurboDisableWithController from "./controllers/turbo_disable_with_controller"
import DarkModeController from "./controllers/dark_mode_controller"

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
