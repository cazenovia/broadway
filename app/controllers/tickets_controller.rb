class TicketsController < ApplicationController
  def create
    @property = Property.find(params[:property_id])
    
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

  def update
    @ticket = Ticket.find(params[:id])
        
    # Update the status if they changed it
    @ticket.status = params.dig(:ticket, :status) if params.dig(:ticket, :status).present?
    
    if @ticket.save
      # If they typed a new note in the update form, attach it to the timeline!
      if params[:ticket_note] && params[:ticket_note][:body].present?
        @ticket.ticket_notes.create!(
          body: params[:ticket_note][:body],
          user: current_user
        )
      end

      render json: { status: "success", message: "Ticket updated!" }, status: :ok
    else
      Rails.logger.error "❌ TICKET UPDATE FAILED: #{@ticket.errors.full_messages} ❌"
      render json: { errors: @ticket.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ticket_params
    params.expect(ticket: [ :title, photos: [] ])
  end
end