# frozen_string_literal: true

require 'test_helper'

# registerControllers is the surface every primitive appears on. A controller that is written but
# not registered -- or registered under a path that 404s for importmap consumers -- does nothing.
class RegisterControllersTest < ActiveSupport::TestCase
  INDEX = File.expand_path('../../app/javascript/rails_ui_kit/index.js', __dir__)
  CONTROLLERS = File.expand_path('../../app/javascript/rails_ui_kit/controllers', __dir__)

  def source
    @source ||= File.read(INDEX)
  end

  {
    'ui--anchor' => 'AnchorController',
    'ui--roving-focus' => 'RovingFocusController',
    'ui--select' => 'SelectController',
    'ui--field' => 'FieldController',
    'ui--character-count' => 'CharacterCountController'
  }.each do |identifier, constant|
    test "registers #{identifier}" do
      assert_includes source, %(application.register("#{identifier}", #{constant}))
    end

    test "imports #{constant} from a file pin_all_from pins" do
      path = source[%r{import #{constant} from "rails_ui_kit/controllers/([a-z_]+)"}, 1]

      assert path, "#{constant} is not imported from rails_ui_kit/controllers/"
      assert File.exist?(File.join(CONTROLLERS, "#{path}.js")), "#{path}.js does not exist under controllers/"
    end
  end
end
