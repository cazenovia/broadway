class TicketNote < ApplicationRecord
belongs_to :ticket
belongs_to :user
validates :body, presence: true
end
