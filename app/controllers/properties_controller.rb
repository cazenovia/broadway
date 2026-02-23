class PropertiesController < ApplicationController
  before_action :set_property, only: %i[ show edit update destroy ]

  # GET /properties or /properties.json
  def index
    # The raw string defining our District (Caroline to Ann, Eastern to Baltimore)
    district_wkt = "POLYGON((-76.5968 39.2845, -76.5968 39.2930, -76.5910 39.2928, -76.5910 39.2843, -76.5968 39.2845))"    @properties = Property.where("ST_Intersects(boundary, ST_GeomFromText(?, 4326))", district_wkt)
                          .with_attached_photo
                          .includes(:tickets, :contacts)
  end

  # GET /properties/1 or /properties/1.json
  def show
  end

  # GET /properties/new
  def new
    @property = Property.new
  end

  # GET /properties/1/edit
  def edit
  end

  # POST /properties or /properties.json
  def create
    @property = Property.new(property_params)

    respond_to do |format|
      if @property.save
        format.html { redirect_to @property, notice: "Property was successfully created." }
        format.json { render :show, status: :created, location: @property }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @property.errors, status: :unprocessable_entity }
      end
    end
  end

# PATCH/PUT /properties/1 or /properties/1.json
  def update
    Rails.logger.warn "🚨 === UPDATE TRIGGERED FOR PROPERTY #{@property.id} === 🚨"
    Rails.logger.warn "📥 RAW PARAMS RECEIVED: #{params[:property].inspect}"
    
    if params.dig(:property, :photo).present?
      file = params[:property][:photo]
      Rails.logger.warn "📸 PHOTO DETECTED IN PAYLOAD! Class: #{file.class}"
      Rails.logger.warn "📸 Name: #{file.original_filename} | Size: #{file.size} bytes" if file.respond_to?(:size)
    else
      Rails.logger.warn "👻 NO PHOTO DETECTED IN PAYLOAD (This is good if we didn't upload one!)"
    end

    safe_params = property_params
    Rails.logger.warn "🛡️ PARAMS AFTER GATEKEEPER: #{safe_params.inspect}"

    respond_to do |format|
      if @property.update(safe_params)
        Rails.logger.warn "✅ DB UPDATE SUCCESSFUL"
        format.html { redirect_to property_url(@property), notice: "Property was successfully updated." }
        format.json { render json: { status: "success", message: "Property updated!" }, status: :ok }
      else
        Rails.logger.warn "❌ DB UPDATE FAILED: #{@property.errors.full_messages}"
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /properties/1 or /properties/1.json
  def destroy
    @property.destroy!

    respond_to do |format|
      format.html { redirect_to properties_path, notice: "Property was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_property
      @property = Property.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def property_params
      p = params.expect(property: [ :address, :owner_name, :zoning, :usage_type, :notes, :photo, :residential_units, :estimated_residents ])
      
      # The Gatekeeper
      if p[:photo].blank? || (p[:photo].respond_to?(:size) && p[:photo].size == 0)
        Rails.logger.warn "🗑️ GATEKEEPER TRIGGERED: Trashing empty photo parameter!"
        p.delete(:photo)
      end
      
      p
    end
end
