import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

  connect() {
    this.isOpen = false
    this.setupClickOutside()
  }

  toggle() {
    this.isOpen = !this.isOpen
    this.updateSidebar()
  }

  close() {
    if (this.isOpen) {
      this.isOpen = false
      this.updateSidebar()
    }
  }

  updateSidebar() {
    if (this.hasSidebarTarget) {
      if (this.isOpen) {
        this.sidebarTarget.classList.add("open")
      } else {
        this.sidebarTarget.classList.remove("open")
      }
    }
  }

  setupClickOutside() {
    document.addEventListener("click", (event) => {
      if (this.isOpen && 
          !this.sidebarTarget.contains(event.target) && 
          !event.target.closest(".sidebar-toggle")) {
        this.close()
      }
    })
  }

  // Handle window resize
  resize() {
    if (window.innerWidth > 768 && this.isOpen) {
      this.close()
    }
  }
}