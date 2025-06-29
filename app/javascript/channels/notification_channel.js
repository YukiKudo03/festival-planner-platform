import consumer from "channels/consumer"

consumer.subscriptions.create("NotificationChannel", {
  connected() {
    console.log("Connected to notification channel");
  },

  disconnected() {
    console.log("Disconnected from notification channel");
  },

  received(data) {
    this.showNotification(data);
    this.updateNotificationCount();
  },

  showNotification(data) {
    // Create toast notification
    const toast = document.createElement('div');
    toast.className = 'toast align-items-center text-white bg-primary border-0 position-fixed';
    toast.style.cssText = 'top: 20px; right: 20px; z-index: 1060;';
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'assertive');
    toast.setAttribute('aria-atomic', 'true');
    
    toast.innerHTML = `
      <div class="d-flex">
        <div class="toast-body">
          <strong>${data.title}</strong><br>
          ${data.message}
        </div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
      </div>
    `;
    
    document.body.appendChild(toast);
    
    const bsToast = new bootstrap.Toast(toast, {
      autohide: true,
      delay: 5000
    });
    bsToast.show();

    // Remove toast element after it's hidden
    toast.addEventListener('hidden.bs.toast', () => {
      toast.remove();
    });

    // Add to notification list if exists
    this.addToNotificationList(data);
  },

  addToNotificationList(data) {
    const notificationList = document.getElementById('notification-list');
    if (notificationList) {
      const notificationItem = document.createElement('div');
      notificationItem.className = 'list-group-item list-group-item-action';
      notificationItem.innerHTML = `
        <div class="d-flex w-100 justify-content-between">
          <h6 class="mb-1">${data.title}</h6>
          <small class="text-muted">今</small>
        </div>
        <p class="mb-1">${data.message}</p>
        <div class="d-flex justify-content-between">
          <small class="text-muted">${data.notification_type}</small>
          <button class="btn btn-sm btn-outline-primary mark-as-read" data-notification-id="${data.id}">
            既読にする
          </button>
        </div>
      `;
      
      notificationList.insertBefore(notificationItem, notificationList.firstChild);
    }
  },

  updateNotificationCount() {
    const badge = document.getElementById('notification-count');
    if (badge) {
      const currentCount = parseInt(badge.textContent) || 0;
      badge.textContent = currentCount + 1;
      badge.style.display = 'inline';
    }
  },

  markAsRead(notificationId) {
    this.perform('mark_as_read', { notification_id: notificationId });
  }
});

// Handle mark as read buttons
document.addEventListener('click', function(e) {
  if (e.target.classList.contains('mark-as-read')) {
    const notificationId = e.target.dataset.notificationId;
    const channel = consumer.subscriptions.subscriptions[0];
    if (channel) {
      channel.markAsRead(notificationId);
    }
    
    // Update UI
    e.target.closest('.list-group-item').classList.add('opacity-50');
    e.target.textContent = '既読';
    e.target.disabled = true;
    
    // Update count
    const badge = document.getElementById('notification-count');
    if (badge) {
      const currentCount = parseInt(badge.textContent) || 0;
      const newCount = Math.max(0, currentCount - 1);
      badge.textContent = newCount;
      if (newCount === 0) {
        badge.style.display = 'none';
      }
    }
  }
});
