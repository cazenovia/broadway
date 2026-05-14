class Add311IdToTicket < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :baltimore_ticket_id, :string
  end
end
