class User < ApplicationRecord
  has_many :tickets
  has_many :ticket_notes
  has_many :contacts, dependent: :destroy
end
