import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = {
    apiKey: String,
    properties: Object
  }

  connect() {
    mapboxgl.accessToken = this.apiKeyValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style: 'mapbox://styles/mapbox/light-v11',
      center: [-76.5938, 39.2865],
      zoom: 16 
    });

    this.map.on('load', () => {
      this.map.addSource('broadway-parcels', {
        type: 'geojson',
        data: this.propertiesValue
      });

      this.map.addLayer({
        id: 'parcel-fills',
        type: 'fill',
        source: 'broadway-parcels',
        paint: {
          'fill-color': [
            'match',
            ['get', 'usage_type'],
            'Retail', '#10B981',
            'Residential', '#3B82F6',
            'Vacant', '#EF4444',
            'Public', '#8B5CF6',
            '#9CA3AF'
          ],
          'fill-opacity': 0.6
        }
      });

      this.map.addLayer({
        id: 'parcel-borders',
        type: 'line',
        source: 'broadway-parcels',
        paint: {
          'line-color': '#000000',
          'line-width': 2
        }
      });

      // THE CLICK HANDLER
      this.map.on('click', 'parcel-fills', (e) => {
        const clickedProperty = e.features[0].properties;

        const form = document.getElementById('property_form');
        if (form) form.action = `/properties/${clickedProperty.id}`;

        const addressEl = document.getElementById('form_address');
        if (addressEl) addressEl.textContent = clickedProperty.address || "Unknown Address";
        
        const usageEl = document.getElementById('form_usage_type');
        if (usageEl) usageEl.value = clickedProperty.usage_type || "Residential";
        
        const notesEl = document.getElementById('form_notes');
        if (notesEl) notesEl.value = clickedProperty.notes || "";
        
        const photoEl = document.getElementById('form_photo');
        if (photoEl) photoEl.value = ""; 

        const statOwner = document.getElementById('stat_owner');
        if (statOwner) statOwner.textContent = clickedProperty.owner || "Unknown";
        
        const statPrice = document.getElementById('stat_price');
        if (statPrice) statPrice.textContent = clickedProperty.sale_price || "N/A";
        
        const statDate = document.getElementById('stat_date');
        if (statDate) statDate.textContent = clickedProperty.sale_date || "Unknown";
        
        const statYear = document.getElementById('stat_year');
        if (statYear) statYear.textContent = clickedProperty.year_built || "Unknown";

        const photoContainer = document.getElementById('photo_container');
        const displayPhoto = document.getElementById('display_photo');
        if (photoContainer && displayPhoto) {
          if (clickedProperty.photo_url) {
            displayPhoto.src = clickedProperty.photo_url;
            photoContainer.classList.remove('hidden');
          } else {
            displayPhoto.src = "";
            photoContainer.classList.add('hidden');
          }
        }

        const ticketsList = document.getElementById('tickets_list');
        if (ticketsList) {
          ticketsList.innerHTML = "";
          
          let tickets = [];
          try {
            // Mapbox sometimes parses JSON arrays automatically, sometimes leaves them as strings
            tickets = typeof clickedProperty.tickets === "string" ? JSON.parse(clickedProperty.tickets) : clickedProperty.tickets || [];
          } catch(err) {
            console.error("Error parsing tickets:", err);
          }
          
          if (tickets.length === 0) {
            ticketsList.innerHTML = '<li class="text-sm text-gray-500 italic p-2">No active tickets.</li>';
          } else {
            tickets.forEach(ticket => {
              const badgeColor = ticket.status === 'open' ? 'bg-yellow-100 text-yellow-800' : 'bg-green-100 text-green-800';
              ticketsList.innerHTML += `
                <li class="flex justify-between items-center p-3 mb-2 bg-white border border-gray-200 rounded-lg shadow-sm">
                  <div>
                    <p class="text-sm font-bold text-gray-800">${ticket.title}</p>
                    <p class="text-[10px] text-gray-500 font-medium">Opened: ${ticket.date}</p>
                  </div>
                  <span class="px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wide ${badgeColor}">${ticket.status}</span>
                </li>
              `;
            });
          }
        }

        const ticketForm = document.getElementById('ticket_form');
        if (ticketForm) {
          ticketForm.action = `/properties/${clickedProperty.id}/tickets`;
          const ticketPropId = document.getElementById('ticket_property_id');
          if (ticketPropId) ticketPropId.value = clickedProperty.id;
        }

        // Trigger the global view toggle function from the HTML
        if (typeof toggleViews === 'function') toggleViews('view_main');
        
        const card = document.getElementById('property_editor_card');
        if (card) card.classList.remove('translate-y-full');
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