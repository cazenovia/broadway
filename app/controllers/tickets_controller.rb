class TicketsController < ApplicationController
  def create
    @property = Property.find(params[:property_id])
    
    @ticket = @property.tickets.build(ticket_params)
    @ticket.user = Current.session.user # <-- Updated!
    @ticket.status = "open" if @ticket.status.blank? 
    
    if @ticket.save
      if params[:ticket_note] && params[:ticket_note][:body].present?
        @ticket.ticket_notes.create!(
          body: params[:ticket_note][:body],
          user: Current.session.user # <-- Updated!
        )
      end

      render json: { status: "success", message: "Ticket created!" }, status: :created
    else
      Rails.logger.error "❌ TICKET SAVE FAILED: #{@ticket.errors.full_messages} ❌"
      render json: { errors: @ticket.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @ticket = Ticket.find(params[:id])
        
    @ticket.status = params.dig(:ticket, :status) if params.dig(:ticket, :status).present?
    
    if @ticket.save
      if params[:ticket_note] && params[:ticket_note][:body].present?
        @ticket.ticket_notes.create!(
          body: params[:ticket_note][:body],
          user: Current.session.user # <-- Updated!
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