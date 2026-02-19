import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = {
    apiKey: String,
    properties: Object // Changed from Array to Object (because it's GeoJSON now)
  }

  connect() {
    mapboxgl.accessToken = this.apiKeyValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style: 'mapbox://styles/mapbox/light-v11', // Switched to a cleaner base map for parcels
      center: [-76.5938, 39.2865],
      zoom: 18 // Zoomed in closer to see the shapes
    });

    // We must wait for the base map to load before adding custom layers
    this.map.on('load', () => {
      
      // 1. Add our GeoJSON data to the map
      this.map.addSource('broadway-parcels', {
        type: 'geojson',
        data: this.propertiesValue
      });

      // 2. Draw the colored outlines (The "Fill")
      this.map.addLayer({
        id: 'parcel-fills',
        type: 'fill',
        source: 'broadway-parcels',
        paint: {
          'fill-color': [
            'match',
            ['get', 'usage'],
            'Retail', '#10B981',      // Green for Retail
            'Residential', '#3B82F6', // Blue for Residential
            'Vacant', '#EF4444',      // Red for Vacant
            '#9CA3AF'                 // Gray for unknown
          ],
          'fill-opacity': 0.5
        }
      });

      // 3. Draw a border around the shapes
      this.map.addLayer({
        id: 'parcel-borders',
        type: 'line',
        source: 'broadway-parcels',
        paint: {
          'line-color': '#ffffff',
          'line-width': 2
        }
      });

      // 4. THE CLICK EVENT ON THE SHAPE
      this.map.on('click', 'parcel-fills', (e) => {
        // Mapbox gives us the data of the specific shape we clicked
        const clickedProperty = e.features[0].properties;
        
        // Trigger the Turbo Frame slide-up!
        const frame = document.getElementById("property_editor");
        frame.src = `/properties/${clickedProperty.id}/edit`;
      });

      // 5. Change the cursor to a pointer when hovering over a building
      this.map.on('mouseenter', 'parcel-fills', () => {
        this.map.getCanvas().style.cursor = 'pointer';
      });
      this.map.on('mouseleave', 'parcel-fills', () => {
        this.map.getCanvas().style.cursor = '';
      });
    });
  }
}