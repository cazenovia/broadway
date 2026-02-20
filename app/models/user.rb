class User < ApplicationRecord
  has_secure_password
  normalizes :email_address, with: ->(e) { e.strip.downcase }
  has_many :tickets
  has_many :ticket_notes
  has_many :contacts, dependent: :destroy
end