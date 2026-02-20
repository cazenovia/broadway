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

    this.map.on('load', () => {
      console.log("3. Base map loaded! Drawing shapes...");
      
      this.map.addSource('broadway-parcels', {
        type: 'geojson',
        data: this.propertiesValue
      });

      // Draw the colored outlines based on usage_type
      this.map.addLayer({
        id: 'parcel-fills',
        type: 'fill',
        source: 'broadway-parcels',
        paint: {
          'fill-color': [
            'match',
            ['get', 'usage_type'],    // Look at the usage_type property
            'Retail', '#10B981',      // Green for Retail
            'Residential', '#3B82F6', // Blue for Residential
            'Vacant', '#EF4444',      // Red for Vacant
            'Public', '#8B5CF6',      // Purple for Public
            '#9CA3AF'                 // Gray for anything else
          ],
          'fill-opacity': 0.6
        }
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

      // THE NEW CLICK HANDLER
      this.map.on('click', 'parcel-fills', (e) => {
        const clickedProperty = e.features[0].properties;

        // 1. Set the Property form destination
        const form = document.getElementById('property_form');
        if (form) form.action = `/properties/${clickedProperty.id}`;

        // 2. Inject standard form fields
        const addressEl = document.getElementById('form_address');
        if (addressEl) addressEl.textContent = clickedProperty.address || "Unknown Address";
        
        const usageEl = document.getElementById('form_usage_type');
        if (usageEl) usageEl.value = clickedProperty.usage_type || "Residential";
        
        const notesEl = document.getElementById('form_notes');
        if (notesEl) notesEl.value = clickedProperty.notes || "";
        
        const photoEl = document.getElementById('form_photo');
        if (photoEl) photoEl.value = ""; 

        // 3. Inject Read-Only Stats
        document.getElementById('stat_owner').textContent = clickedProperty.owner || "Unknown";
        document.getElementById('stat_price').textContent = clickedProperty.sale_price || "N/A";
        document.getElementById('stat_date').textContent = clickedProperty.sale_date || "Unknown";
        document.getElementById('stat_year').textContent = clickedProperty.year_built || "Unknown";

        // 4. Handle Canonical Photo Display
        const photoContainer = document.getElementById('photo_container');
        const displayPhoto = document.getElementById('display_photo');
        if (clickedProperty.photo_url) {
          displayPhoto.src = clickedProperty.photo_url;
          photoContainer.classList.remove('hidden');
        } else {
          displayPhoto.src = "";
          photoContainer.classList.add('hidden');
        }

        // 5. Populate the Tickets List
        const ticketsList = document.getElementById('tickets_list');
        ticketsList.innerHTML = ""; // Clear out previous property's tickets
        
        // Safely parse the JSON string Mapbox creates
        const tickets = JSON.parse(clickedProperty.tickets || "[]");
        
        if (tickets.length === 0) {
          ticketsList.innerHTML = '<li class="text-sm text-gray-500 italic p-2">No active tickets.</li>';
        } else {
          tickets.forEach(ticket => {
            // Give open tickets a yellow badge, resolved tickets a green badge
            const badgeColor = ticket.status === 'open' ? 'bg-yellow-100 text-yellow-800' : 'bg-green-100 text-green-800';
            ticketsList.innerHTML += `
              <li class="flex justify-between items-center p-3 bg-white border border-gray-200 rounded-lg shadow-sm">
                <div>
                  <p class="text-sm font-bold text-gray-800">${ticket.title}</p>
                  <p class="text-[10px] text-gray-500 font-medium">Opened: ${ticket.date}</p>
                </div>
                <span class="px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wide ${badgeColor}">${ticket.status}</span>
              </li>
            `;
          });
        }

        // 6. Prep the New Ticket Form routing
        const ticketForm = document.getElementById('ticket_form');
        if (ticketForm) {
          ticketForm.action = `/properties/${clickedProperty.id}/tickets`;
          document.getElementById('ticket_property_id').value = clickedProperty.id;
        }

        // 7. Reset the view state and slide the card up
        toggleViews('view_main');
        const card = document.getElementById('property_editor_card');
        if (card) card.classList.remove('translate-y-full');
      });
  }
}