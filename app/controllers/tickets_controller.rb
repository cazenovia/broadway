class TicketsController < ApplicationController
  def create
    @property = Property.find(params[:property_id])
    
    # Safely grab a user. If the dummy worker doesn't exist, just grab the very first user in the DB!
    current_user = User.find_or_create_by!(email: "worker@broadway.app") do |u|
      # If your User model requires a password, we provide a dummy one here
      u.password = "password123" if u.respond_to?(:password=)
    end
    
    @ticket = @property.tickets.build(ticket_params)
    @ticket.user = current_user
    @ticket.status = "open" if @ticket.status.blank? # Provide a default status!
    
    if @ticket.save
      # If they typed an initial note, create the TicketNote record
      if params[:ticket_note] && params[:ticket_note][:body].present?
        @ticket.ticket_notes.create!(
          body: params[:ticket_note][:body],
          user: current_user
        )
      end

      # Reply to the JavaScript fetch request with a pure JSON success
      render json: { status: "success", message: "Ticket created!" }, status: :created
    else
      # 🚨 THE TRIPWIRE: Print the exact database validation error to the logs! 🚨
      Rails.logger.error "❌ TICKET SAVE FAILED: #{@ticket.errors.full_messages} ❌"
      
      render json: { errors: @ticket.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ticket_params
    params.expect(ticket: [ :title, photos: [] ])
  end
end