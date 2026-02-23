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
      // Use the SW and NE corners to perfectly frame the district on load!
      bounds: [
        [-76.591550, 39.285867], // Southeast (Lowest point)
        [-76.598568, 39.292665]  // Northwest (Highest point)
      ],
      fitBoundsOptions: { padding: 50 } // Gives a nice 50px visual margin around the edges
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
            'Commercial', '#10B981',
            'Residential', '#3B82F6',
            'Vacant', '#EF4444',
            'Mixed-Use', '#8B5CF6',
            'Government', '#ebab00',
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

      this.map.on('click', 'parcel-fills', (e) => {
        const clickedProperty = e.features[0].properties;

        // 1. POPULATE PROPERTY ATTRIBUTES
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
        const formUnits = document.getElementById('form_units');
        if (formUnits) formUnits.value = clickedProperty.residential_units || 0;
        const formResidents = document.getElementById('form_residents');
        if (formResidents) formResidents.value = clickedProperty.estimated_residents || 0;
        
        const statUnits = document.getElementById('stat_units');
        if (statUnits) statUnits.textContent = clickedProperty.residential_units || 0;
        const statResidents = document.getElementById('stat_residents');
        if (statResidents) statResidents.textContent = clickedProperty.estimated_residents || 0;

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

        // 2. POPULATE TICKETS
        const ticketsList = document.getElementById('tickets_list');
        let tickets = [];
        if (ticketsList) {
          ticketsList.innerHTML = "";
          try {
            tickets = typeof clickedProperty.tickets === "string" ? JSON.parse(clickedProperty.tickets) : clickedProperty.tickets || [];
          } catch(err) { console.error(err); }
          
          if (tickets.length === 0) {
            ticketsList.innerHTML = '<li class="text-sm text-slate-500 italic p-2">No active tickets.</li>';
          } else {
            window.currentPropertyTickets = tickets; 
            tickets.forEach(ticket => {
              const badgeColor = ticket.status.toLowerCase() === 'open' ? 'bg-yellow-100 text-yellow-800' : 'bg-green-100 text-green-800';
              ticketsList.innerHTML += `
                <li onclick="openTicketDetail(${ticket.id})" class="cursor-pointer hover:bg-slate-50 flex justify-between items-center p-4 mb-3 bg-white border border-slate-200 rounded-2xl shadow-sm transition-transform active:scale-[0.98]">
                  <div>
                    <p class="text-sm font-bold text-slate-800">${ticket.title}</p>
                    <p class="text-[10px] text-slate-500 font-bold uppercase tracking-wider mt-1">Opened: ${ticket.date} • ${ticket.notes ? ticket.notes.length : 0} Notes</p>
                  </div>
                  <span class="px-3 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest ${badgeColor}">${ticket.status}</span>
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
        const ticketCountEl = document.getElementById('ticket_count');
        if (ticketCountEl) ticketCountEl.textContent = tickets.length;


        // 3. POPULATE CONTACTS
        const contactsList = document.getElementById('contacts_list');
        let contacts = [];
        if (contactsList) {
          contactsList.innerHTML = "";
          try {
            contacts = typeof clickedProperty.contacts === "string" ? JSON.parse(clickedProperty.contacts) : clickedProperty.contacts || [];
          } catch(err) { console.error(err); }

          if (contacts.length === 0) {
            contactsList.innerHTML = '<li class="text-sm text-slate-500 italic p-2">No contacts recorded.</li>';
          } else {
            window.currentPropertyContacts = contacts;
            contacts.forEach(contact => {
              contactsList.innerHTML += `
                <li onclick="openContactDetail(${contact.id})" class="cursor-pointer hover:bg-slate-50 flex justify-between items-center p-4 mb-3 bg-white border border-slate-200 rounded-2xl shadow-sm transition-transform active:scale-[0.98]">
                  <div>
                    <p class="text-sm font-bold text-slate-800">${contact.person}</p>
                    <p class="text-[10px] text-slate-500 font-bold uppercase tracking-wider mt-1">${contact.display_date} • ${contact.method}</p>
                  </div>
                  <span class="px-3 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest bg-emerald-100 text-emerald-800 border border-emerald-200">${contact.role}</span>
                </li>
              `;
            });
          }
        }
        const contactForm = document.getElementById('contact_form');
        if (contactForm) {
          contactForm.action = `/properties/${clickedProperty.id}/contacts`;
          const contactPropId = document.getElementById('contact_property_id');
          if (contactPropId) contactPropId.value = clickedProperty.id;
        }
        const contactCountEl = document.getElementById('contact_count');
        if (contactCountEl) contactCountEl.textContent = contacts.length;

        // Reset Card to initial state
        if (typeof switchTab === 'function') switchTab('info');
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