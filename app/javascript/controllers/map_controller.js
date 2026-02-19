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
            'Public', '#8B5CF6',      // Purple for Public (added for your seed data!)
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