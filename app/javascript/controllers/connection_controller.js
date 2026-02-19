import { Controller } from "@hotwired/stimulus"
import Dexie from "dexie"
import { SyncService } from "sync_service"

export default class extends Controller {
  static targets = ["badge", "icon", "text", "lastSync", "spinner"]

  connect() {
    this.updateStatus()
    window.addEventListener("online", () => this.updateStatus())
    window.addEventListener("offline", () => this.updateStatus())
    this.updateSyncDisplay()
  }

  async updateStatus() {
    if (navigator.onLine) {
      // Transition to ONLINE state
      this.badgeTarget.classList.replace("bg-red-50", "bg-gray-50")
      this.badgeTarget.classList.replace("border-red-200", "border-gray-200")
      
      this.iconTarget.classList.replace("bg-red-500", "bg-green-500")
      this.iconTarget.classList.add("animate-pulse")
      
      this.textTarget.textContent = "Online"
      this.textTarget.classList.replace("text-red-700", "text-gray-700")

      // Trigger sync and show spinner
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
      // Transition to OFFLINE state
      this.badgeTarget.classList.replace("bg-gray-50", "bg-red-50")
      this.badgeTarget.classList.replace("border-gray-200", "border-red-200")
      
      this.iconTarget.classList.replace("bg-green-500", "bg-red-500")
      this.iconTarget.classList.remove("animate-pulse")
      
      this.textTarget.textContent = "Offline"
      this.textTarget.classList.replace("text-gray-700", "text-red-700")
      
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

  async handleOfflineSubmit(event) {
    if (!navigator.onLine) {
      event.preventDefault()
      const form = event.target
      const formData = new FormData(form)
      const propertyId = form.action.split('/').pop()

      await SyncService.saveToOutbox(propertyId, formData)
      
      alert("Note saved locally! It will upload automatically when signal returns.")
      
      const frame = document.getElementById("property_editor")
      if (frame) frame.src = "" 
    }
  }
}