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
import MediaQueryController from "rails_ui_kit/controllers/media_query_controller"
import AnchorController from "rails_ui_kit/controllers/anchor_controller"
import RovingFocusController from "rails_ui_kit/controllers/roving_focus_controller"
import PresenceController from "rails_ui_kit/controllers/presence_controller"
import OverlayController from "rails_ui_kit/controllers/overlay_controller"
import SelectController from "rails_ui_kit/controllers/select_controller"

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
  MediaQueryController,
  AnchorController,
  RovingFocusController,
  PresenceController,
  OverlayController,
  SelectController
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
  application.register("ui--tooltip", TooltipController)
  application.register("ui--popover", PopoverController)
  application.register("ui--media-query", MediaQueryController)
  application.register("ui--anchor", AnchorController)
  application.register("ui--roving-focus", RovingFocusController)
  application.register("ui--presence", PresenceController)
  application.register("ui--overlay", OverlayController)
  application.register("ui--select", SelectController)
}
