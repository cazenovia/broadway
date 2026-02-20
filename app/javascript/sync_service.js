import Dexie from "dexie"

const db = new Dexie('BroadwayOfflineDB');
db.version(1).stores({
  outbox: '++id, propertyId, status' // auto-incrementing ID
});

export const SyncService = {
  // Save a form to the browser for later
  async saveToOutbox(propertyId, formData) {
    const data = {
      propertyId: propertyId,
      usage_type: formData.get('property[usage_type]'),
      notes: formData.get('property[notes]'),
      photo: formData.get('property[photo]'),
      timestamp: new Date().toISOString(),
      status: 'pending'
    };
    return await db.outbox.add(data);
  },

  // Send all pending items to the Rails server
  async syncOutbox() { 
    const items = await db.outbox.toArray();
    if (items.length === 0) return;

    console.log(`Syncing ${items.length} items...`);
    
    // Grab the security token from the webpage's <head> safely
    const csrfMetaTag = document.querySelector('meta[name="csrf-token"]');
    const csrfToken = csrfMetaTag ? csrfMetaTag.content : "";

    for (const item of items) {
      try {
        // 2. Reconstruct the FormData object so Rails understands it
        const formData = new FormData();
        if (item.usage_type) formData.append('property[usage_type]', item.usage_type);
        if (item.notes) formData.append('property[notes]', item.notes);
        
        // Only append the photo if a real file was attached
        if (item.photo && item.photo.name) {
          formData.append('property[photo]', item.photo);
        }

        const response = await fetch(`/properties/${item.propertyId}`, {
          method: 'PATCH',
          credentials: 'same-origin', // <-- ADD THIS LINE HERE TOO!
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/json"
          },
          body: formData
        });

        if (response.ok) {
          await db.outbox.delete(item.id);
        } else {
          console.error(`Failed to sync property ${item.propertyId}: Server returned ${response.status}`);
        }
      } catch (error) {
        console.error("Sync failed, device might still be offline.", error);
        break; // Stop trying if the network failed
      }
    }
  }
};