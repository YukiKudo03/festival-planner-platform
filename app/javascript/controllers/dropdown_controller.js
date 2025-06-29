import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Initialize dropdown
  }

  toggle(event) {
    event.preventDefault()
    this.menuTarget.classList.toggle("show")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("show")
    }
  }

  signOut(event) {
    event.preventDefault()
    
    if (confirm("ログアウトしますか？")) {
      // Create a form and submit it
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = event.target.href
      
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = 'delete'
      form.appendChild(methodInput)
      
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = document.querySelector('meta[name="csrf-token"]').content
      form.appendChild(tokenInput)
      
      document.body.appendChild(form)
      form.submit()
    }
  }
}