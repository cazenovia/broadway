import { Controller } from "@hotwired/stimulus"
import Dexie from "dexie" 
import { SyncService } from "sync_service"

export default class extends Controller {
  static targets = ["badge", "icon", "text", "lastSync", "spinner"]

  connect() {
    console.log("Connection Controller Booted. Status:", navigator.onLine ? "Online" : "Offline")
    this.updateStatus()
    this.updateSyncDisplay()
  }

  async updateStatus() {
    console.log("Network change detected. Now:", navigator.onLine ? "Online" : "Offline")
    
    // Wipe the slate clean
    this.badgeTarget.classList.remove("bg-gray-50", "border-gray-200", "bg-red-50", "border-red-200")
    this.iconTarget.classList.remove("bg-green-500", "bg-red-500", "animate-pulse")
    this.textTarget.classList.remove("text-gray-700", "text-red-700")

    if (navigator.onLine) {
      // ONLINE
      this.badgeTarget.classList.add("bg-gray-50", "border-gray-200")
      this.iconTarget.classList.add("bg-green-500", "animate-pulse")
      this.textTarget.textContent = "Online"
      this.textTarget.classList.add("text-gray-700")

      // Trigger Sync
      this.spinnerTarget.classList.remove("hidden")
      try {
        await SyncService.syncOutbox()
        this.recordSync()
      } catch (e) {
        console.error("Sync failed:", e)
      } finally {
        this.spinnerTarget.classList.add("hidden")
      }

    } else {
      // OFFLINE
      this.badgeTarget.classList.add("bg-red-50", "border-red-200")
      this.iconTarget.classList.add("bg-red-500")
      this.textTarget.textContent = "Offline"
      this.textTarget.classList.add("text-red-700")
      this.spinnerTarget.classList.add("hidden")
    }
  }

  recordSync() {
    const now = new Date().toLocaleString([], { hour: '2-digit', minute: '2-digit' })
    localStorage.setItem("lastSyncTime", now)
    this.updateSyncDisplay()
  }

  updateSyncDisplay() {
    const time = localStorage.getItem("lastSyncTime") || "Never"
    if (this.hasLastSyncTarget) {
      this.lastSyncTarget.textContent = time
    }
  }

  async handleSubmit(event) {
    event.preventDefault() 
    
    const form = event.target
    const formData = new FormData(form) 
    const propertyId = form.action.split('/').pop()

    const photoInput = form.querySelector('input[type="file"]')
    if (photoInput && photoInput.files.length === 0) {
      formData.delete('property[photo]')
    }
    
    if (!navigator.onLine) {
      // OFFLINE MODE
      await SyncService.saveToOutbox(propertyId, formData)
      alert("Offline Mode: Note saved locally! It will upload automatically.")
      
      const card = document.getElementById("property_editor_card")
      if (card) card.classList.add("translate-y-full") 
      
    } else {
      // ONLINE MODE
      try {
        const csrfMetaTag = document.querySelector('meta[name="csrf-token"]')
        const csrfToken = csrfMetaTag ? csrfMetaTag.content : ""
        
        // FORCE Rails to treat this as an API request by appending .json
        const actionUrl = form.action.endsWith('.json') ? form.action : form.action + '.json';
        
        const response = await fetch(actionUrl, {
          method: 'PATCH',
          credentials: 'same-origin', 
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "application/json"
          },
          body: formData 
        });

        if (response.ok) {
          const card = document.getElementById("property_editor_card")
          if (card) card.classList.add("translate-y-full") 
          window.location.reload(); 
        } else {
          console.error("Server error during save.")
          alert("Error saving to server. Please try again.")
        }
      } catch (e) { 
        console.error("Network failed during send, saving to outbox", e)
        await SyncService.saveToOutbox(propertyId, formData)
        const card = document.getElementById("property_editor_card")
        if (card) card.classList.add("translate-y-full") 
      }
    }
  }
}