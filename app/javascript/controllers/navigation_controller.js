import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    this.updateActiveLink()
    
    // Listen for turbo frame navigation
    document.addEventListener("turbo:frame-load", () => {
      this.updateActiveLink()
    })
    
    document.addEventListener("turbo:visit", () => {
      this.updateActiveLink()
    })
  }

  updateActiveLink() {
    // Remove active class from all links
    this.linkTargets.forEach(link => {
      link.classList.remove("active")
    })

    // Add active class to current page link
    const currentPath = window.location.pathname
    this.linkTargets.forEach(link => {
      const linkPath = new URL(link.href).pathname
      if (currentPath === linkPath || 
          (linkPath !== "/" && currentPath.startsWith(linkPath))) {
        link.classList.add("active")
      }
    })
  }

  navigate(event) {
    // Add loading state
    const link = event.currentTarget
    link.classList.add("loading")
    
    // Remove loading state after navigation
    setTimeout(() => {
      link.classList.remove("loading")
    }, 500)
  }
}