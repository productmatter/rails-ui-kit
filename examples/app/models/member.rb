# frozen_string_literal: true

require 'active_model'

# The demo resource behind docs/guides/forms.md: one record with each shape a Rails form has to
# get right -- a plain attribute, an enum, a belongs_to, a has_many edited as ids and a nested
# record. The docs app has no database, so this is ActiveModel standing in for ActiveRecord, and
# each association is written the way ActiveRecord would behave: the belongs_to error lands on
# :team, the has_many error on :roles, the nested record keeps its own errors.
class Member
  include ActiveModel::API

  SEED = { id: 1, name: 'Sam Rivera', status: 'active', team_id: 1, role_ids: [1, 3],
           address_attributes: { city: 'Lisbon' } }.freeze

  attr_accessor :id, :name, :status, :team_id
  attr_reader :role_ids, :address

  # What `enum :status, { active: 0, invited: 1, suspended: 2 }` publishes.
  def self.statuses
    { 'active' => 0, 'invited' => 1, 'suspended' => 2 }
  end

  validates :name, presence: true
  validates :status, inclusion: { in: statuses.keys }
  validate :team_exists
  validate :at_least_one_role
  validate :address_valid

  class << self
    def find(id)
      raise ArgumentError, "no member #{id}" unless id.to_i == SEED[:id]

      new(**stored)
    end

    def write(attributes)
      @stored = attributes
    end

    # Called from each browser test's setup, so no test inherits another's save.
    def reset!
      @stored = nil
    end

    private

    def stored
      @stored ||= SEED.deep_dup
    end
  end

  def initialize(attributes = {})
    @role_ids = []
    @address = Address.new
    super
  end

  # What a checkbox group posts: ids as strings, with Rails' blank entry, which ActiveRecord's
  # ids writer drops.
  def role_ids=(values)
    @role_ids = Array(values).compact_blank.map(&:to_i)
  end

  def address_attributes=(attributes)
    @address = Address.new(city: attributes[:city])
  end

  def update(attributes)
    assign_attributes(attributes)
    return false unless valid?

    self.class.write(id: id, name: name, status: status, team_id: team_id, role_ids: role_ids,
                     address_attributes: { city: address.city })
    true
  end

  def persisted?
    true
  end

  def team
    Team.all.find { |team| team.id == team_id.to_i }
  end

  def roles
    Role.all.select { |role| role_ids.include?(role.id) }
  end

  private

  # belongs_to :team -- Rails validates the association, not the foreign key the form edits.
  def team_exists
    errors.add(:team, 'must exist') if team.nil?
  end

  # has_many :roles -- validated as roles, edited as role_ids.
  def at_least_one_role
    errors.add(:roles, 'needs at least one role') if role_ids.empty?
  end

  def address_valid
    errors.add(:address, :invalid) if address.invalid?
  end
end
