class ApplicationTask < ApplicationRecord
  STATUSES = %w[
    preparing
    waiting_for_user
    ready_for_review
    approved
    submitted
  ].freeze

  validates :application_name, presence: true
  validates :status, inclusion: { in: STATUSES }
end