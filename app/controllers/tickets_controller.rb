class TicketsController < ApplicationController
  def create
    @property = Property.find(params[:property_id])
    
    # We grab our dummy user since we haven't built authentication yet!
    current_user = User.find_by(email: "worker@broadway.app")
    
    @ticket = @property.tickets.build(ticket_params)
    @ticket.user = current_user
    
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
      render json: { errors: @ticket.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ticket_params
    # Notice we permit an array of photos [] so users can upload multiple!
    params.expect(ticket: [ :title, photos: [] ])
  end
end