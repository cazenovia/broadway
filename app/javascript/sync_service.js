import Dexie from 'dexie';

// Define the local database
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
      photo: formData.get('property[photo]'), // Large files are fine in IndexedDB!
      timestamp: new Date().toISOString(),
      status: 'pending'
    };
    return await db.outbox.add(data);
  },

  // Send all pending items to the Rails server
  async syncOutbox() {
    const pending = await db.outbox.where('status').equals('pending').toArray();
    if (pending.length === 0) return;

    console.log(`Syncing ${pending.length} items...`);

    for (const item of pending) {
      const formData = new FormData();
      formData.append('property[usage_type]', item.usage_type);
      formData.append('property[notes]', item.notes);
      if (item.photo) formData.append('property[photo]', item.photo);

      try {
        const response = await fetch(`/properties/${item.propertyId}`, {
          method: 'PATCH',
          body: formData,
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
            'Accept': 'text/vnd.turbo-stream.html'
          }
        });

        if (response.ok) {
          await db.outbox.delete(item.id);
          console.log(`Property ${item.propertyId} synced!`);
        }
      } catch (err) {
        console.error("Sync failed for item", item.id, err);
      }
    }
  }
};