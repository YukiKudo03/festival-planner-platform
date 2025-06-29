// Bootstrap setup for Rails with Turbo
import { Dropdown, Modal, Toast, Tooltip, Popover } from 'bootstrap'

document.addEventListener('turbo:load', () => {
  // Initialize Bootstrap dropdowns
  const dropdownTriggerList = document.querySelectorAll('[data-bs-toggle="dropdown"]')
  const dropdownList = [...dropdownTriggerList].map(dropdownTriggerEl => new Dropdown(dropdownTriggerEl))

  // Initialize Bootstrap modals
  const modalTriggerList = document.querySelectorAll('[data-bs-toggle="modal"]')
  const modalList = [...modalTriggerList].map(modalTriggerEl => new Modal(modalTriggerEl))

  // Initialize Bootstrap tooltips
  const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]')
  const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new Tooltip(tooltipTriggerEl))

  // Initialize Bootstrap popovers
  const popoverTriggerList = document.querySelectorAll('[data-bs-toggle="popover"]')
  const popoverList = [...popoverTriggerList].map(popoverTriggerEl => new Popover(popoverTriggerEl))
})