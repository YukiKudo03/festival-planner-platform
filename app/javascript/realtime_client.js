// Realtime Client for Festival Planner Platform

class RealtimeClient {
  constructor() {
    this.subscription = null;
    this.connectionState = 'disconnected';
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 1000; // Start with 1 second
    this.pingInterval = null;
    this.presenceLocation = null;
    this.typingTimeouts = new Map();
    this.callbacks = new Map();
    this.isTabActive = true;
    
    this.init();
  }

  init() {
    this.setupVisibilityHandling();
    this.connect();
  }

  connect() {
    if (this.subscription) {
      this.disconnect();
    }

    try {
      this.subscription = App.cable.subscriptions.create('RealtimeUpdatesChannel', {
        connected: () => this.handleConnected(),
        disconnected: () => this.handleDisconnected(),
        rejected: () => this.handleRejected(),
        received: (data) => this.handleReceived(data)
      });
    } catch (error) {
      console.error('Failed to create realtime subscription:', error);
      this.scheduleReconnect();
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }
    
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
    
    this.connectionState = 'disconnected';
    this.notifyConnectionChange();
  }

  handleConnected() {
    console.log('Realtime connection established');
    this.connectionState = 'connected';
    this.reconnectAttempts = 0;
    this.reconnectDelay = 1000;
    
    this.startPingInterval();
    this.joinCurrentPresence();
    this.notifyConnectionChange();
  }

  handleDisconnected() {
    console.log('Realtime connection lost');
    this.connectionState = 'disconnected';
    
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
    
    this.notifyConnectionChange();
    this.scheduleReconnect();
  }

  handleRejected() {
    console.error('Realtime connection rejected');
    this.connectionState = 'rejected';
    this.notifyConnectionChange();
  }

  handleReceived(data) {
    console.log('Realtime data received:', data);
    
    switch (data.type) {
      case 'connection_established':
        this.handleConnectionEstablished(data);
        break;
      case 'pong':
        this.handlePong(data);
        break;
      case 'festival_update':
        this.handleFestivalUpdate(data);
        break;
      case 'task_update':
        this.handleTaskUpdate(data);
        break;
      case 'budget_update':
        this.handleBudgetUpdate(data);
        break;
      case 'vendor_update':
        this.handleVendorUpdate(data);
        break;
      case 'chat_message':
        this.handleChatMessage(data);
        break;
      case 'notification':
        this.handleNotification(data);
        break;
      case 'user_joined':
        this.handleUserJoined(data);
        break;
      case 'user_left':
        this.handleUserLeft(data);
        break;
      case 'typing_start':
        this.handleTypingStart(data);
        break;
      case 'typing_stop':
        this.handleTypingStop(data);
        break;
      case 'live_data_response':
        this.handleLiveDataResponse(data);
        break;
      case 'system_alert':
        this.handleSystemAlert(data);
        break;
      default:
        this.triggerCallback('unknown_message', data);
    }
  }

  scheduleReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      this.connectionState = 'failed';
      this.notifyConnectionChange();
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1); // Exponential backoff
    
    console.log(`Scheduling reconnect attempt ${this.reconnectAttempts} in ${delay}ms`);
    
    setTimeout(() => {
      if (this.connectionState === 'disconnected') {
        this.connect();
      }
    }, delay);
  }

  startPingInterval() {
    this.pingInterval = setInterval(() => {
      if (this.isConnected() && this.isTabActive) {
        this.ping();
      }
    }, 30000); // Ping every 30 seconds
  }

  ping() {
    if (this.subscription) {
      this.subscription.perform('ping', { timestamp: Date.now() });
    }
  }

  handlePong(data) {
    const latency = Date.now() - (data.server_time * 1000);
    this.triggerCallback('ping_response', { latency });
  }

  // Presence Management
  joinPresence(location, page = null) {
    this.presenceLocation = location;
    
    if (this.subscription) {
      this.subscription.perform('join_presence', {
        location: location,
        page: page || window.location.pathname
      });
    }
  }

  leavePresence() {
    if (this.subscription && this.presenceLocation) {
      this.subscription.perform('leave_presence', {
        location: this.presenceLocation
      });
    }
    this.presenceLocation = null;
  }

  joinCurrentPresence() {
    // Auto-join presence based on current page
    const path = window.location.pathname;
    let location = 'general';
    
    if (path.includes('/festivals/')) {
      const festivalId = path.match(/\/festivals\/(\d+)/)?.[1];
      if (festivalId) {
        location = `festival_${festivalId}`;
      }
    } else if (path.includes('/chat')) {
      location = 'chat';
    } else if (path.includes('/forums')) {
      location = 'forums';
    } else if (path.includes('/admin')) {
      location = 'admin';
    }
    
    this.joinPresence(location);
  }

  // Typing Indicators
  startTyping(context, contextId) {
    if (this.subscription) {
      this.subscription.perform('typing_start', {
        context: context,
        context_id: contextId
      });
    }
  }

  stopTyping(context, contextId) {
    if (this.subscription) {
      this.subscription.perform('typing_stop', {
        context: context,
        context_id: contextId
      });
    }
  }

  // Live Data Requests
  requestLiveData(type, resourceId) {
    if (this.subscription) {
      this.subscription.perform('request_live_data', {
        type: type,
        resource_id: resourceId
      });
    }
  }

  // Activity Tracking
  trackActivity(activityType, activityData = {}) {
    if (this.subscription) {
      this.subscription.perform('update_user_activity', {
        activity_type: activityType,
        activity_data: activityData
      });
    }
  }

  // Festival Subscription Management
  subscribeToFestival(festivalId) {
    if (this.subscription) {
      this.subscription.perform('subscribe_to_festival', {
        festival_id: festivalId
      });
    }
  }

  unsubscribeFromFestival(festivalId) {
    if (this.subscription) {
      this.subscription.perform('unsubscribe_from_festival', {
        festival_id: festivalId
      });
    }
  }

  // Event Handlers
  handleConnectionEstablished(data) {
    console.log('Connection established with festivals:', data.subscribed_festivals);
    this.triggerCallback('connection_established', data);
  }

  handleFestivalUpdate(data) {
    this.triggerCallback('festival_update', data);
    this.showUpdateNotification('Festival Updated', data.message);
  }

  handleTaskUpdate(data) {
    this.triggerCallback('task_update', data);
    
    if (data.action === 'completed') {
      this.showUpdateNotification('Task Completed', `Task "${data.task.title}" has been completed`);
    } else if (data.action === 'assigned') {
      this.showUpdateNotification('Task Assigned', `You have been assigned a new task: "${data.task.title}"`);
    }
  }

  handleBudgetUpdate(data) {
    this.triggerCallback('budget_update', data);
    
    if (data.action === 'expense_approved') {
      this.showUpdateNotification('Expense Approved', `Expense of $${data.amount} has been approved`);
    } else if (data.action === 'budget_warning') {
      this.showUpdateNotification('Budget Warning', data.message, 'warning');
    }
  }

  handleVendorUpdate(data) {
    this.triggerCallback('vendor_update', data);
    
    if (data.action === 'application_approved') {
      this.showUpdateNotification('Application Approved', 'Your vendor application has been approved!');
    }
  }

  handleChatMessage(data) {
    this.triggerCallback('chat_message', data);
    
    // Show notification if not in the chat room
    if (!window.location.pathname.includes(`/chat_rooms/${data.chat_room_id}`)) {
      this.showUpdateNotification(
        `New message in ${data.room_name}`,
        `${data.sender_name}: ${data.message.substring(0, 50)}...`
      );
    }
  }

  handleNotification(data) {
    this.triggerCallback('notification', data);
    this.showUpdateNotification(data.title, data.message, data.type || 'info');
  }

  handleUserJoined(data) {
    this.triggerCallback('user_joined', data);
    this.updatePresenceIndicator(data.user, 'joined');
  }

  handleUserLeft(data) {
    this.triggerCallback('user_left', data);
    this.updatePresenceIndicator({ id: data.user_id }, 'left');
  }

  handleTypingStart(data) {
    this.triggerCallback('typing_start', data);
    this.showTypingIndicator(data.user, data.context, data.context_id);
  }

  handleTypingStop(data) {
    this.triggerCallback('typing_stop', data);
    this.hideTypingIndicator(data.user_id, data.context, data.context_id);
  }

  handleLiveDataResponse(data) {
    this.triggerCallback('live_data_response', data);
    this.triggerCallback(`live_data_${data.data_type}`, data);
  }

  handleSystemAlert(data) {
    this.triggerCallback('system_alert', data);
    this.showSystemAlert(data.message, data.severity || 'info');
  }

  // UI Update Methods
  showUpdateNotification(title, message, type = 'info') {
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(title, { body: message });
    }
    
    // Also show in-app notification
    this.showInAppNotification(title, message, type);
  }

  showInAppNotification(title, message, type = 'info') {
    const container = this.getOrCreateNotificationContainer();
    
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show notification-item`;
    notification.innerHTML = `
      <strong>${title}</strong>
      <p class="mb-0">${message}</p>
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    container.appendChild(notification);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 150);
      }
    }, 5000);
  }

  showSystemAlert(message, severity) {
    const alertClass = severity === 'error' ? 'danger' : severity;
    const alert = document.createElement('div');
    alert.className = `alert alert-${alertClass} alert-dismissible fade show system-alert`;
    alert.innerHTML = `
      <i class="fas fa-exclamation-triangle me-2"></i>
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.insertBefore(alert, document.body.firstChild);
  }

  getOrCreateNotificationContainer() {
    let container = document.getElementById('realtime-notifications');
    if (!container) {
      container = document.createElement('div');
      container.id = 'realtime-notifications';
      container.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 9999;
        max-width: 400px;
      `;
      document.body.appendChild(container);
    }
    return container;
  }

  updatePresenceIndicator(user, action) {
    const indicator = document.querySelector(`[data-presence-user="${user.id}"]`);
    if (indicator) {
      if (action === 'joined') {
        indicator.classList.add('online');
        indicator.title = `${user.name} is online`;
      } else {
        indicator.classList.remove('online');
        indicator.title = `${user.name} was recently online`;
      }
    }
  }

  showTypingIndicator(user, context, contextId) {
    const containerId = `typing-${context}-${contextId}`;
    let container = document.getElementById(containerId);
    
    if (!container) {
      container = document.createElement('div');
      container.id = containerId;
      container.className = 'typing-indicator';
      
      // Try to find appropriate location to insert
      const contextElement = document.querySelector(`[data-${context}="${contextId}"]`);
      if (contextElement) {
        contextElement.appendChild(container);
      }
    }
    
    const userId = user.id;
    let userIndicator = container.querySelector(`[data-typing-user="${userId}"]`);
    
    if (!userIndicator) {
      userIndicator = document.createElement('span');
      userIndicator.dataset.typingUser = userId;
      userIndicator.className = 'typing-user';
      userIndicator.textContent = `${user.name} is typing...`;
      container.appendChild(userIndicator);
    }
    
    // Clear existing timeout
    if (this.typingTimeouts.has(userId)) {
      clearTimeout(this.typingTimeouts.get(userId));
    }
    
    // Set new timeout to hide indicator
    const timeout = setTimeout(() => {
      this.hideTypingIndicator(userId, context, contextId);
    }, 10000);
    
    this.typingTimeouts.set(userId, timeout);
  }

  hideTypingIndicator(userId, context, contextId) {
    const containerId = `typing-${context}-${contextId}`;
    const container = document.getElementById(containerId);
    
    if (container) {
      const userIndicator = container.querySelector(`[data-typing-user="${userId}"]`);
      if (userIndicator) {
        userIndicator.remove();
      }
      
      // Remove container if empty
      if (container.children.length === 0) {
        container.remove();
      }
    }
    
    // Clear timeout
    if (this.typingTimeouts.has(userId)) {
      clearTimeout(this.typingTimeouts.get(userId));
      this.typingTimeouts.delete(userId);
    }
  }

  // Visibility Handling
  setupVisibilityHandling() {
    document.addEventListener('visibilitychange', () => {
      this.isTabActive = !document.hidden;
      
      if (this.isTabActive) {
        // Tab became active
        this.joinCurrentPresence();
      } else {
        // Tab became inactive
        this.leavePresence();
      }
    });

    window.addEventListener('beforeunload', () => {
      this.leavePresence();
      this.disconnect();
    });
  }

  // Callback Management
  on(event, callback) {
    if (!this.callbacks.has(event)) {
      this.callbacks.set(event, []);
    }
    this.callbacks.get(event).push(callback);
  }

  off(event, callback) {
    if (this.callbacks.has(event)) {
      const callbacks = this.callbacks.get(event);
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  triggerCallback(event, data) {
    if (this.callbacks.has(event)) {
      this.callbacks.get(event).forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(`Error in realtime callback for ${event}:`, error);
        }
      });
    }
  }

  notifyConnectionChange() {
    this.triggerCallback('connection_change', {
      state: this.connectionState,
      attempts: this.reconnectAttempts
    });
  }

  // Status Methods
  isConnected() {
    return this.connectionState === 'connected';
  }

  getConnectionState() {
    return this.connectionState;
  }

  getReconnectAttempts() {
    return this.reconnectAttempts;
  }
}

// Initialize and export
let realtimeClient = null;

document.addEventListener('DOMContentLoaded', () => {
  if (typeof App !== 'undefined' && App.cable) {
    realtimeClient = new RealtimeClient();
    window.realtimeClient = realtimeClient;
  }
});

export default RealtimeClient;