import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = {
    apiKey: String,
    properties: Object
  }

  connect() {
    console.log("1. Stimulus Connected!");
    console.log("2. Here is the GeoJSON from Rails:", this.propertiesValue);

    mapboxgl.accessToken = this.apiKeyValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style: 'mapbox://styles/mapbox/light-v11',
      center: [-76.5938, 39.2865],
      zoom: 16 
    });

    this.map.on('click', 'parcel-fills', (e) => {
        const clickedProperty = e.features[0].properties;

        // 1. Set the form's destination URL dynamically
        const form = document.getElementById('property_form');
        if (form) form.action = `/properties/${clickedProperty.id}`;

        // 2. Inject the data into the HTML fields
        // (Using standard DOM methods to update the hidden template)
        const addressEl = document.getElementById('form_address');
        if (addressEl) addressEl.textContent = clickedProperty.address || "Unknown Address";
        
        const usageEl = document.getElementById('form_usage_type');
        if (usageEl) usageEl.value = clickedProperty.usage_type || "Residential";
        
        const notesEl = document.getElementById('form_notes');
        if (notesEl) notesEl.value = clickedProperty.notes || "";
        
        const photoEl = document.getElementById('form_photo');
        if (photoEl) photoEl.value = ""; // Always clear the old photo input!

        // 3. Slide the card up onto the screen
        const card = document.getElementById('property_editor_card');
        if (card) card.classList.remove('translate-y-full');
      });
      // Draw high-visibility BLACK borders
      this.map.addLayer({
        id: 'parcel-borders',
        type: 'line',
        source: 'broadway-parcels',
        paint: {
          'line-color': '#000000',
          'line-width': 2
        }
      });

      this.map.on('click', 'parcel-fills', (e) => {
        const clickedProperty = e.features[0].properties;
        const frame = document.getElementById("property_editor");
        frame.src = `/properties/${clickedProperty.id}/edit`;
      });

      this.map.on('mouseenter', 'parcel-fills', () => {
        this.map.getCanvas().style.cursor = 'pointer';
      });
      this.map.on('mouseleave', 'parcel-fills', () => {
        this.map.getCanvas().style.cursor = '';
      });
    });
  }
}