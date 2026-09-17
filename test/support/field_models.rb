# frozen_string_literal: true

require 'active_model'

# ActiveModel::API records for the model-bound Field tests: no database and no ActiveRecord,
# because Field may rely on nothing beyond ActiveModel's shape (ui-field-model-binding
# § Business rules, rule 4). Each exists for one naming, label or validation case.
module FieldModels
  class User
    include ActiveModel::API

    attr_accessor :email, :nickname, :bio, :city, :password, :avatar

    validates :email, presence: true
  end

  # A module namespace with no relative naming: param key admin_user.
  module Admin
    class User
      include ActiveModel::API

      attr_accessor :email
    end
  end

  class Person
    include ActiveModel::API

    attr_accessor :email

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Person')
    end
  end

  # What an isolated engine does for its models: relative naming, so the param key is post
  # while model_name.singular is field_models_blog_post.
  module Blog
    def self.use_relative_model_naming?
      true
    end

    class Post
      include ActiveModel::API

      attr_accessor :title
    end
  end

  class Comment
    include ActiveModel::API

    attr_accessor :body

    validates :body, presence: true
  end

  # An ActiveRecord-shaped value: a _before_type_cast reader and a came_from_user? predicate,
  # which ActiveModel::API alone doesn't define.
  class Measurement
    include ActiveModel::API

    attr_accessor :age_before_type_cast, :age_came_from_user

    def age
      age_before_type_cast.to_i
    end

    def age_came_from_user?
      age_came_from_user
    end
  end

  # One attribute per validation shape required detection must weigh.
  class Validated
    include ActiveModel::API

    ATTRIBUTES = %i[plain with_message strict conditional unless_conditional on_create on_update on_custom
                    allow_nil allow_blank length numericality inclusion format comparison acceptance
                    custom_method each_validator validates_with unknown_option].freeze

    attr_accessor(*ATTRIBUTES)

    class NotBlankValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add(attribute, :blank) if value.blank?
      end
    end

    class WholeRecordValidator < ActiveModel::Validator
      def validate(record)
        record.errors.add(:validates_with, :blank) if record.validates_with.blank?
      end
    end

    validates :plain, presence: true
    validates :with_message, presence: { message: 'is needed' }
    validates :strict, presence: { strict: true }
    validates :conditional, presence: true, if: -> { true }
    validates :unless_conditional, presence: true, unless: -> { false }
    validates :on_create, presence: true, on: :create
    validates :on_update, presence: true, on: :update
    validates :on_custom, presence: true, on: :publish
    validates :allow_nil, presence: { allow_nil: true }
    validates :allow_blank, presence: { allow_blank: true }
    validates :length, length: { minimum: 1 }
    validates :numericality, numericality: true
    validates :inclusion, inclusion: { in: %w[a b] }
    validates :format, format: { with: /\A.+\z/ }
    validates :comparison, comparison: { greater_than: 0 }
    validates :acceptance, acceptance: true
    validate :custom_method_present
    validates_with NotBlankValidator, attributes: [:each_validator]
    validates_with WholeRecordValidator
    # A presence validator carrying an option the kit doesn't know, as a future Rails or a gem
    # might add: it has to read as not required.
    validates_with ActiveModel::Validations::PresenceValidator, attributes: [:unknown_option], if_feature: :beta

    private

    def custom_method_present
      errors.add(:custom_method, :blank) if custom_method.blank?
    end
  end

  # A record whose class has neither validators_on nor human_attribute_name.
  class Bare
    attr_reader :errors
    attr_accessor :email

    Name = Struct.new(:param_key, :i18n_key, :singular)

    def initialize
      @errors = Hash.new { |hash, key| hash[key] = [] }
    end

    def to_model
      self
    end

    def model_name
      Name.new('bare', :bare, 'bare')
    end
  end
end
