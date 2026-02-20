class Ticket < ApplicationRecord
  belongs_to :property
  belongs_to :user
  has_many :ticket_notes, dependent: :destroy
  
  has_many_attached :photos 

  validates :title, presence: true
  validates :status, inclusion: { in: %w[open resolved] }
end
