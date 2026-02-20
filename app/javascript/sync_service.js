import Dexie from "dexie"

const db = new Dexie('BroadwayOfflineDB');
// We bumped to version 2 to support our new generic payload format!
db.version(2).stores({
  outbox: '++id, url, method, status' 
});

export const SyncService = {
  // Save ANY form to the browser for later
  async saveToOutbox(url, method, formData) {
    // Convert FormData to an array of objects to safely store in IndexedDB
    const payload = [];
    for (const [key, value] of formData.entries()) {
      payload.push({ key, value });
    }

    const data = {
      url: url,
      method: method,
      payload: payload,
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
        const formData = new FormData();
        
        // Reconstruct the generic payload 
        if (item.payload) {
          item.payload.forEach(entry => formData.append(entry.key, entry.value));
        } else {
          // Fallback for any lingering V1 Property Update offline records
          if (item.usage_type) formData.append('property[usage_type]', item.usage_type);
          if (item.notes) formData.append('property[notes]', item.notes);
          if (item.photo && item.photo.name) formData.append('property[photo]', item.photo);
          item.url = `/properties/${item.propertyId}.json`;
          item.method = 'PATCH';
        }

        const response = await fetch(item.url, {
          method: item.method,
          credentials: 'same-origin',
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/json"
          },
          body: formData 
        });

        if (response.ok) {
          await db.outbox.delete(item.id);
        } else {
          console.error(`Failed to sync item ${item.id}: Server returned ${response.status}`);
        }
      } catch (error) {
        console.error("Sync failed, device might still be offline.", error);
        break; // Stop trying if the network failed
      }
    }
  }
};