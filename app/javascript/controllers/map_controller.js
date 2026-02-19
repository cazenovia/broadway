import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  connect() {
    mapboxgl.accessToken = this.apiKeyValue;

    this.map = new mapboxgl.Map({
      container: this.element,
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [-76.5938, 39.2865], // Centered on S Broadway
      zoom: 16
    });

    // Add a marker for every property
    const properties = JSON.parse(this.element.dataset.properties)
    
    properties.forEach((prop) => {
      new mapboxgl.Marker({ color: "#FF0000" }) // Red dots
        .setLngLat([prop.lon, prop.lat])
        .setPopup(new mapboxgl.Popup().setHTML(`<h3>${prop.address}</h3><p>${prop.usage}</p>`))
        .addTo(this.map);
    })
  }
}