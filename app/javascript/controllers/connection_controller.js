import { Controller } from "@hotwired/stimulus"
import { SyncService } from "sync_service"


export default class extends Controller {
  static targets = ["banner", "lastSync"]

  connect() {
    // Check initial status
    this.updateStatus()
    
    // Listen for the OS telling the browser it gained/lost connection
    window.addEventListener("online", () => this.updateStatus())
    window.addEventListener("offline", () => this.updateStatus())
    
    // Initialize the last sync time if it doesn't exist yet
    if (!localStorage.getItem("lastSyncTime")) {
      this.recordSync()
    }
    this.updateSyncDisplay()
  }

  updateStatus() {
    if (navigator.onLine) {
    this.bannerTarget.classList.add("hidden")
    SyncService.syncOutbox().then(() => {
      this.recordSync() // Update the "Last Sync" timestamp after successful upload
    })
    } else {
      this.bannerTarget.classList.remove("hidden")
    }
  }

  recordSync() {
    const now = new Date().toLocaleString()
    localStorage.setItem("lastSyncTime", now)
    this.updateSyncDisplay()
  }

  updateSyncDisplay() {
    if (this.hasLastSyncTarget) {
      this.lastSyncTarget.textContent = localStorage.getItem("lastSyncTime")
    }
  }
}