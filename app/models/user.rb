class User < ApplicationRecord
  has_many :tickets
  has_many :ticket_notes
end
