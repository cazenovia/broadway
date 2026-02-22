class Property < ApplicationRecord
  has_many :tickets, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_one_attached :photo
  after_create_commit -> { FetchPropertyUnitsJob.perform_later(id) }
end
