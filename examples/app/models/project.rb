# frozen_string_literal: true

require 'active_model'

# The demo resource behind docs/guides/modal-and-turbo.md. The docs app has no database, so the
# "table" is a hash of attribute hashes held in the class -- but everything a controller touches
# (find, update, destroy, errors, dom_id) is the ActiveModel API an ActiveRecord model exposes,
# so the guide's controller and views are the ones a host app writes against its own records.
#
# Rows are stored as attribute hashes rather than objects, so a record handed to a request is
# never the one another request is mutating, exactly as a row read from a database isn't.
class Project
  include ActiveModel::API

  SEED = [
    { id: 1, name: 'Acme rebrand', summary: 'Brand system, launch site and campaign assets' },
    { id: 2, name: 'Q3 campaign', summary: 'Paid social, landing pages and reporting' },
    { id: 3, name: 'Website refresh', summary: 'Information architecture and a new design system' }
  ].freeze

  attr_accessor :id, :name, :summary

  validates :name, presence: true
  validates :summary, length: { maximum: 80 }
  # A failure only the server can catch: the browser's own required can't know another project
  # already has this name. Presence alone would never reach the server, so it could never
  # demonstrate the 422 re-render.
  validate :name_available

  class << self
    def all
      store.values.sort_by { |attributes| attributes[:id] }.map { |attributes| new(**attributes) }
    end

    def find(id)
      new(**store.fetch(id.to_i))
    end

    def exists?(id)
      store.key?(id.to_i)
    end

    # Called from each browser test's setup, so no test inherits another's edits.
    def reset!
      lock.synchronize { @store = seeded_store }
    end

    def write(attributes)
      lock.synchronize { store[attributes[:id]] = attributes }
    end

    def delete(id)
      lock.synchronize { store.delete(id) }
    end

    private

    # Never taken under `lock`: write and delete hold it while they reach for the store, and a
    # Mutex is not reentrant.
    def store
      @store ||= seeded_store
    end

    def seeded_store
      SEED.to_h { |attributes| [attributes[:id], attributes.dup] }
    end

    def lock
      @lock ||= Mutex.new
    end
  end

  def update(attributes)
    assign_attributes(attributes)
    return false unless valid?

    self.class.write(id: id, name: name, summary: summary)
    true
  end

  def destroy
    self.class.delete(id)
  end

  def persisted?
    id.present? && self.class.exists?(id)
  end

  # Static demo data, so the activity modal (the read-only frame-target pattern) has something
  # real to read.
  def activity
    [
      "#{name} created",
      "#{name} shared with the design team",
      'Summary updated'
    ]
  end

  private

  def name_available
    return if name.blank?

    taken = self.class.all.any? { |other| other.id != id && other.name.casecmp?(name) }
    errors.add(:name, 'is already taken') if taken
  end
end
