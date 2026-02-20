class Property < ApplicationRecord
  has_many :tickets, dependent: :destroy
  has_one_attached :photo
end
