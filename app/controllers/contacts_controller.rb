class ContactsController < ApplicationController
  def create
    @property = Property.find(params[:property_id])
        
    @contact = @property.contacts.build(contact_params)
    @contact.user = current_user
    
    if @contact.save
      render json: { status: "success", message: "Contact created!" }, status: :created
    else
      Rails.logger.error "❌ CONTACT SAVE FAILED: #{@contact.errors.full_messages} ❌"
      render json: { errors: @contact.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    @contact = Contact.find(params[:id])
    
    if @contact.update(contact_params)
      render json: { status: "success", message: "Contact updated!" }, status: :ok
    else
      Rails.logger.error "❌ CONTACT UPDATE FAILED: #{@contact.errors.full_messages} ❌"
      render json: { errors: @contact.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.expect(contact: [ :contact_date, :contact_person, :contact_person_role, :contact_method, :contact_summary ])
  end
end