import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { 
    reactableType: String, 
    reactableId: Number 
  }

  connect() {
    console.log("Reactions controller connected")
  }

  toggle(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const reactionType = button.dataset.reactionType
    const isActive = button.dataset.active === "true"
    
    // Optimistic UI update
    this.updateButtonState(button, !isActive)
    
    // Send request to server
    this.sendReactionRequest(reactionType, isActive)
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          this.updateAllButtons(data.reaction_summary, data.user_reaction)
        } else {
          // Revert optimistic update on error
          this.updateButtonState(button, isActive)
          console.error('Reaction update failed:', data.error)
        }
      })
      .catch(error => {
        // Revert optimistic update on error
        this.updateButtonState(button, isActive)
        console.error('Reaction request failed:', error)
        this.showErrorToast('リアクションの更新に失敗しました')
      })
  }

  sendReactionRequest(reactionType, isCurrentlyActive) {
    const url = '/reactions'
    const method = isCurrentlyActive ? 'DELETE' : 'POST'
    
    const body = {
      reactable_type: this.reactableTypeValue,
      reactable_id: this.reactableIdValue,
      reaction: {
        reaction_type: reactionType
      }
    }

    return fetch(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Accept': 'application/json'
      },
      body: JSON.stringify(body)
    })
  }

  updateButtonState(button, isActive) {
    const countSpan = button.querySelector('.reaction-count')
    let currentCount = parseInt(countSpan.textContent) || 0
    
    if (isActive) {
      button.dataset.active = "true"
      button.classList.add('btn-primary')
      button.classList.remove('btn-outline-secondary')
      countSpan.textContent = currentCount + 1
    } else {
      button.dataset.active = "false"
      button.classList.remove('btn-primary')
      button.classList.add('btn-outline-secondary')
      countSpan.textContent = Math.max(0, currentCount - 1)
    }
  }

  updateAllButtons(reactionSummary, userReaction) {
    // Find all reaction buttons in this controller's scope
    const buttons = this.element.querySelectorAll('.reaction-btn')
    
    buttons.forEach(button => {
      const reactionType = button.dataset.reactionType
      const count = reactionSummary[reactionType] || 0
      const isUserReaction = userReaction === reactionType
      
      // Update count
      const countSpan = button.querySelector('.reaction-count')
      countSpan.textContent = count
      
      // Update active state
      button.dataset.active = isUserReaction.toString()
      
      if (isUserReaction) {
        button.classList.add('btn-primary')
        button.classList.remove('btn-outline-secondary')
      } else {
        button.classList.remove('btn-primary')
        button.classList.add('btn-outline-secondary')
      }
      
      // Hide button if count is 0 and user hasn't reacted (for posts)
      if (count === 0 && !isUserReaction && button.closest('.forum-post')) {
        button.style.display = 'none'
      } else {
        button.style.display = 'inline-block'
      }
    })
  }

  showErrorToast(message) {
    // Create a simple toast notification
    const toast = document.createElement('div')
    toast.className = 'toast show position-fixed top-0 end-0 m-3'
    toast.style.zIndex = '9999'
    toast.innerHTML = `
      <div class="toast-header bg-danger text-white">
        <strong class="me-auto">エラー</strong>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast"></button>
      </div>
      <div class="toast-body">
        ${message}
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
    }, 5000)
    
    // Remove on close button click
    const closeButton = toast.querySelector('.btn-close')
    closeButton?.addEventListener('click', () => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
    })
  }
}