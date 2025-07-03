import { Controller } from "@hotwired/stimulus"
import { Sortable } from "sortablejs"

export default class extends Controller {
  static targets = ["canvas", "sidebar", "toolbar", "elementPalette", "propertyPanel", "coordinateDisplay"]
  static values = { 
    venueId: Number,
    layoutData: Object,
    gridSize: { type: Number, default: 10 },
    snapToGrid: { type: Boolean, default: true },
    showGrid: { type: Boolean, default: true }
  }

  connect() {
    console.log("Layout editor connected")
    this.selectedElements = new Set()
    this.draggedElement = null
    this.startPos = { x: 0, y: 0 }
    this.canvasOffset = { x: 0, y: 0 }
    this.scale = 1
    this.isSpacePressed = false
    this.isPanning = false
    this.panStart = { x: 0, y: 0 }
    
    this.initializeCanvas()
    this.initializeEventListeners()
    this.initializePalette()
    this.renderLayout()
  }

  disconnect() {
    this.removeEventListeners()
  }

  initializeCanvas() {
    const canvas = this.canvasTarget
    canvas.style.position = 'relative'
    canvas.style.overflow = 'hidden'
    canvas.style.cursor = 'default'
    canvas.style.userSelect = 'none'
    
    // Add grid background
    if (this.showGridValue) {
      this.addGridBackground()
    }
  }

  addGridBackground() {
    const canvas = this.canvasTarget
    const gridSize = this.gridSizeValue
    const gridPattern = `
      <defs>
        <pattern id="grid" width="${gridSize}" height="${gridSize}" patternUnits="userSpaceOnUse">
          <path d="M ${gridSize} 0 L 0 0 0 ${gridSize}" fill="none" stroke="#e0e0e0" stroke-width="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#grid)" />
    `
    
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    svg.innerHTML = gridPattern
    svg.style.position = 'absolute'
    svg.style.top = '0'
    svg.style.left = '0'
    svg.style.width = '100%'
    svg.style.height = '100%'
    svg.style.pointerEvents = 'none'
    svg.style.zIndex = '0'
    
    canvas.insertBefore(svg, canvas.firstChild)
  }

  initializeEventListeners() {
    this.canvasTarget.addEventListener('mousedown', this.handleMouseDown.bind(this))
    this.canvasTarget.addEventListener('mousemove', this.handleMouseMove.bind(this))
    this.canvasTarget.addEventListener('mouseup', this.handleMouseUp.bind(this))
    this.canvasTarget.addEventListener('click', this.handleClick.bind(this))
    this.canvasTarget.addEventListener('wheel', this.handleWheel.bind(this))
    
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
    document.addEventListener('keyup', this.handleKeyUp.bind(this))
  }

  removeEventListeners() {
    document.removeEventListener('keydown', this.handleKeyDown.bind(this))
    document.removeEventListener('keyup', this.handleKeyUp.bind(this))
  }

  initializePalette() {
    if (!this.hasElementPaletteTarget) return
    
    const palette = this.elementPaletteTarget
    const elementTypes = [
      { type: 'entrance', name: '入口', icon: '🚪', color: '#28a745' },
      { type: 'exit', name: '出口', icon: '🚪', color: '#dc3545' },
      { type: 'stage', name: 'ステージ', icon: '🎭', color: '#6f42c1' },
      { type: 'restroom', name: 'トイレ', icon: '🚻', color: '#17a2b8' },
      { type: 'food_court', name: 'フードコート', icon: '🍽️', color: '#fd7e14' },
      { type: 'information', name: '案内所', icon: 'ℹ️', color: '#007bff' },
      { type: 'parking', name: '駐車場', icon: '🅿️', color: '#6c757d' },
      { type: 'path', name: '通路', icon: '🛤️', color: '#ffc107' },
      { type: 'security', name: '警備', icon: '🛡️', color: '#e83e8c' },
      { type: 'storage', name: '倉庫', icon: '📦', color: '#20c997' }
    ]

    elementTypes.forEach(elementType => {
      const paletteItem = document.createElement('div')
      paletteItem.className = 'palette-item'
      paletteItem.draggable = true
      paletteItem.dataset.elementType = elementType.type
      paletteItem.innerHTML = `
        <span class="palette-icon">${elementType.icon}</span>
        <span class="palette-name">${elementType.name}</span>
      `
      paletteItem.style.backgroundColor = elementType.color + '20'
      paletteItem.style.border = `2px solid ${elementType.color}`
      
      paletteItem.addEventListener('dragstart', this.handlePaletteDragStart.bind(this))
      palette.appendChild(paletteItem)
    })
  }

  renderLayout() {
    const canvas = this.canvasTarget
    
    // Clear existing layout elements (keep grid)
    const existingElements = canvas.querySelectorAll('.layout-element')
    existingElements.forEach(el => el.remove())
    
    // Render venue areas
    if (this.layoutDataValue.venue_areas) {
      this.layoutDataValue.venue_areas.forEach(area => {
        this.renderVenueArea(area)
      })
    }
    
    // Render booths
    if (this.layoutDataValue.booths) {
      this.layoutDataValue.booths.forEach(booth => {
        this.renderBooth(booth)
      })
    }
    
    // Render layout elements
    if (this.layoutDataValue.layout_elements) {
      this.layoutDataValue.layout_elements.forEach(element => {
        this.renderLayoutElement(element)
      })
    }
  }

  renderVenueArea(area) {
    const areaElement = document.createElement('div')
    areaElement.className = 'layout-element venue-area'
    areaElement.dataset.elementId = area.id
    areaElement.dataset.elementType = 'venue_area'
    areaElement.style.position = 'absolute'
    areaElement.style.left = `${area.x_position}px`
    areaElement.style.top = `${area.y_position}px`
    areaElement.style.width = `${area.width}px`
    areaElement.style.height = `${area.height}px`
    areaElement.style.backgroundColor = area.color || '#f8f9fa'
    areaElement.style.border = '2px solid #dee2e6'
    areaElement.style.borderRadius = '4px'
    areaElement.style.opacity = '0.8'
    areaElement.style.cursor = 'move'
    areaElement.style.zIndex = '10'
    
    if (area.rotation) {
      areaElement.style.transform = `rotate(${area.rotation}deg)`
    }
    
    const label = document.createElement('div')
    label.className = 'element-label'
    label.textContent = area.name
    label.style.position = 'absolute'
    label.style.top = '4px'
    label.style.left = '4px'
    label.style.fontSize = '12px'
    label.style.fontWeight = 'bold'
    label.style.color = '#495057'
    label.style.pointerEvents = 'none'
    
    areaElement.appendChild(label)
    this.canvasTarget.appendChild(areaElement)
  }

  renderBooth(booth) {
    const boothElement = document.createElement('div')
    boothElement.className = 'layout-element booth'
    boothElement.dataset.elementId = booth.id
    boothElement.dataset.elementType = 'booth'
    boothElement.style.position = 'absolute'
    boothElement.style.left = `${booth.x_position}px`
    boothElement.style.top = `${booth.y_position}px`
    boothElement.style.width = `${booth.width}px`
    boothElement.style.height = `${booth.height}px`
    boothElement.style.backgroundColor = this.getBoothColor(booth.status)
    boothElement.style.border = '2px solid #6c757d'
    boothElement.style.borderRadius = '2px'
    boothElement.style.cursor = 'move'
    boothElement.style.zIndex = '20'
    
    if (booth.rotation) {
      boothElement.style.transform = `rotate(${booth.rotation}deg)`
    }
    
    const label = document.createElement('div')
    label.className = 'element-label'
    label.textContent = booth.booth_number
    label.style.position = 'absolute'
    label.style.top = '50%'
    label.style.left = '50%'
    label.style.transform = 'translate(-50%, -50%)'
    label.style.fontSize = '10px'
    label.style.fontWeight = 'bold'
    label.style.color = '#fff'
    label.style.textShadow = '1px 1px 1px rgba(0,0,0,0.5)'
    label.style.pointerEvents = 'none'
    
    boothElement.appendChild(label)
    this.canvasTarget.appendChild(boothElement)
  }

  renderLayoutElement(element) {
    const elementDiv = document.createElement('div')
    elementDiv.className = 'layout-element layout-element-custom'
    elementDiv.dataset.elementId = element.id
    elementDiv.dataset.elementType = element.element_type
    elementDiv.style.position = 'absolute'
    elementDiv.style.left = `${element.x_position}px`
    elementDiv.style.top = `${element.y_position}px`
    elementDiv.style.width = `${element.width}px`
    elementDiv.style.height = `${element.height}px`
    elementDiv.style.backgroundColor = element.color || '#007bff'
    elementDiv.style.border = '2px solid #0056b3'
    elementDiv.style.borderRadius = '4px'
    elementDiv.style.cursor = 'move'
    elementDiv.style.zIndex = element.layer || '30'
    
    if (element.rotation) {
      elementDiv.style.transform = `rotate(${element.rotation}deg)`
    }
    
    const icon = this.getElementIcon(element.element_type)
    const label = document.createElement('div')
    label.className = 'element-label'
    label.innerHTML = `${icon} ${element.name}`
    label.style.position = 'absolute'
    label.style.top = '50%'
    label.style.left = '50%'
    label.style.transform = 'translate(-50%, -50%)'
    label.style.fontSize = '11px'
    label.style.fontWeight = 'bold'
    label.style.color = '#fff'
    label.style.textAlign = 'center'
    label.style.pointerEvents = 'none'
    
    elementDiv.appendChild(label)
    this.canvasTarget.appendChild(elementDiv)
  }

  getBoothColor(status) {
    const colors = {
      'available': '#28a745',
      'assigned': '#ffc107',
      'occupied': '#dc3545',
      'reserved': '#6f42c1',
      'maintenance': '#6c757d'
    }
    return colors[status] || '#007bff'
  }

  getElementIcon(elementType) {
    const icons = {
      'entrance': '🚪',
      'exit': '🚪',
      'stage': '🎭',
      'restroom': '🚻',
      'food_court': '🍽️',
      'information': 'ℹ️',
      'parking': '🅿️',
      'path': '🛤️',
      'security': '🛡️',
      'storage': '📦'
    }
    return icons[elementType] || '📍'
  }

  handleMouseDown(event) {
    const element = event.target.closest('.layout-element')
    
    if (this.isSpacePressed) {
      // Pan mode
      this.isPanning = true
      this.panStart = { x: event.clientX, y: event.clientY }
      this.canvasTarget.style.cursor = 'grabbing'
      event.preventDefault()
      return
    }
    
    if (element) {
      this.startDrag(element, event)
    } else {
      this.clearSelection()
    }
  }

  handleMouseMove(event) {
    if (this.isPanning) {
      const deltaX = event.clientX - this.panStart.x
      const deltaY = event.clientY - this.panStart.y
      
      this.canvasOffset.x += deltaX
      this.canvasOffset.y += deltaY
      
      this.canvasTarget.style.transform = `translate(${this.canvasOffset.x}px, ${this.canvasOffset.y}px) scale(${this.scale})`
      
      this.panStart = { x: event.clientX, y: event.clientY }
      return
    }
    
    if (this.draggedElement) {
      this.updateDraggedElement(event)
    }
    
    this.updateCoordinateDisplay(event)
  }

  handleMouseUp(event) {
    if (this.isPanning) {
      this.isPanning = false
      this.canvasTarget.style.cursor = this.isSpacePressed ? 'grab' : 'default'
      return
    }
    
    if (this.draggedElement) {
      this.finalizeDrag(event)
    }
  }

  handleClick(event) {
    const element = event.target.closest('.layout-element')
    
    if (element) {
      if (event.ctrlKey || event.metaKey) {
        // Multi-select
        this.toggleSelection(element)
      } else {
        // Single select
        this.selectElement(element)
      }
    }
  }

  handleWheel(event) {
    if (event.ctrlKey || event.metaKey) {
      // Zoom
      event.preventDefault()
      const delta = event.deltaY > 0 ? 0.9 : 1.1
      this.scale = Math.max(0.1, Math.min(3, this.scale * delta))
      this.canvasTarget.style.transform = `translate(${this.canvasOffset.x}px, ${this.canvasOffset.y}px) scale(${this.scale})`
    }
  }

  handleKeyDown(event) {
    switch (event.key) {
      case ' ':
        if (!this.isSpacePressed) {
          this.isSpacePressed = true
          this.canvasTarget.style.cursor = 'grab'
        }
        event.preventDefault()
        break
      case 'Delete':
      case 'Backspace':
        this.deleteSelectedElements()
        break
      case 'c':
        if (event.ctrlKey || event.metaKey) {
          this.copySelectedElements()
        }
        break
      case 'v':
        if (event.ctrlKey || event.metaKey) {
          this.pasteElements()
        }
        break
      case 'z':
        if (event.ctrlKey || event.metaKey) {
          if (event.shiftKey) {
            this.redo()
          } else {
            this.undo()
          }
        }
        break
    }
  }

  handleKeyUp(event) {
    if (event.key === ' ') {
      this.isSpacePressed = false
      this.canvasTarget.style.cursor = 'default'
    }
  }

  handlePaletteDragStart(event) {
    const elementType = event.target.dataset.elementType
    event.dataTransfer.setData('text/plain', JSON.stringify({
      type: 'new_element',
      element_type: elementType
    }))
    event.dataTransfer.effectAllowed = 'copy'
  }

  startDrag(element, event) {
    this.draggedElement = element
    this.startPos = { x: event.clientX, y: event.clientY }
    
    const rect = element.getBoundingClientRect()
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    
    this.elementOffset = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    }
    
    element.style.zIndex = '1000'
    element.style.opacity = '0.8'
    
    event.preventDefault()
  }

  updateDraggedElement(event) {
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    let newX = event.clientX - canvasRect.left - this.elementOffset.x
    let newY = event.clientY - canvasRect.top - this.elementOffset.y
    
    // Snap to grid
    if (this.snapToGridValue) {
      newX = Math.round(newX / this.gridSizeValue) * this.gridSizeValue
      newY = Math.round(newY / this.gridSizeValue) * this.gridSizeValue
    }
    
    this.draggedElement.style.left = `${newX}px`
    this.draggedElement.style.top = `${newY}px`
  }

  finalizeDrag(event) {
    if (!this.draggedElement) return
    
    const elementId = this.draggedElement.dataset.elementId
    const elementType = this.draggedElement.dataset.elementType
    
    const newX = parseFloat(this.draggedElement.style.left)
    const newY = parseFloat(this.draggedElement.style.top)
    
    // Reset visual state
    this.draggedElement.style.zIndex = ''
    this.draggedElement.style.opacity = ''
    
    // Update position on server
    this.updateElementPosition(elementId, elementType, newX, newY)
    
    this.draggedElement = null
  }

  updateElementPosition(elementId, elementType, x, y) {
    const url = `/admin/venues/${this.venueIdValue}/layout_elements/${elementId}/update_position`
    const data = {
      layout_element: {
        x_position: x,
        y_position: y
      }
    }
    
    fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(data => {
      if (data.overlaps && data.overlaps.length > 0) {
        this.showOverlapWarning(data.overlaps)
      }
    })
    .catch(error => {
      console.error('Error updating position:', error)
    })
  }

  selectElement(element) {
    this.clearSelection()
    this.selectedElements.add(element)
    element.classList.add('selected')
    this.updatePropertyPanel(element)
  }

  toggleSelection(element) {
    if (this.selectedElements.has(element)) {
      this.selectedElements.delete(element)
      element.classList.remove('selected')
    } else {
      this.selectedElements.add(element)
      element.classList.add('selected')
    }
    this.updatePropertyPanel()
  }

  clearSelection() {
    this.selectedElements.forEach(element => {
      element.classList.remove('selected')
    })
    this.selectedElements.clear()
    this.updatePropertyPanel()
  }

  updatePropertyPanel(element = null) {
    if (!this.hasPropertyPanelTarget) return
    
    const panel = this.propertyPanelTarget
    
    if (element) {
      const elementId = element.dataset.elementId
      const elementType = element.dataset.elementType
      
      panel.innerHTML = `
        <h6>Properties</h6>
        <div class="mb-2">
          <label>Type:</label>
          <span>${elementType}</span>
        </div>
        <div class="mb-2">
          <label>X:</label>
          <input type="number" class="form-control form-control-sm" value="${parseFloat(element.style.left)}" data-property="x">
        </div>
        <div class="mb-2">
          <label>Y:</label>
          <input type="number" class="form-control form-control-sm" value="${parseFloat(element.style.top)}" data-property="y">
        </div>
        <div class="mb-2">
          <label>Width:</label>
          <input type="number" class="form-control form-control-sm" value="${parseFloat(element.style.width)}" data-property="width">
        </div>
        <div class="mb-2">
          <label>Height:</label>
          <input type="number" class="form-control form-control-sm" value="${parseFloat(element.style.height)}" data-property="height">
        </div>
      `
    } else {
      panel.innerHTML = '<p class="text-muted">Select an element to edit properties</p>'
    }
  }

  updateCoordinateDisplay(event) {
    if (!this.hasCoordinateDisplayTarget) return
    
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    const x = event.clientX - canvasRect.left
    const y = event.clientY - canvasRect.top
    
    this.coordinateDisplayTarget.textContent = `X: ${Math.round(x)}, Y: ${Math.round(y)}`
  }

  showOverlapWarning(overlaps) {
    // Create toast notification for overlaps
    const toast = document.createElement('div')
    toast.className = 'toast show position-fixed top-0 end-0 m-3'
    toast.style.zIndex = '9999'
    toast.innerHTML = `
      <div class="toast-header bg-warning">
        <strong class="me-auto">Layout Warning</strong>
        <button type="button" class="btn-close" data-bs-dismiss="toast"></button>
      </div>
      <div class="toast-body">
        ${overlaps.length} overlap(s) detected. Please adjust element positions.
      </div>
    `
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.remove()
    }, 5000)
  }

  deleteSelectedElements() {
    // Implementation for deleting selected elements
    console.log('Delete selected elements')
  }

  copySelectedElements() {
    // Implementation for copying selected elements
    console.log('Copy selected elements')
  }

  pasteElements() {
    // Implementation for pasting elements
    console.log('Paste elements')
  }

  undo() {
    // Implementation for undo
    console.log('Undo')
  }

  redo() {
    // Implementation for redo
    console.log('Redo')
  }
}