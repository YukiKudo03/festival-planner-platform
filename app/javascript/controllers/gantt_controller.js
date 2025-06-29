import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="gantt"
export default class extends Controller {
  static targets = ["chart", "timeline", "tasks", "legend"]
  static values = { 
    tasks: Array, 
    dateRange: Object,
    festival: String 
  }

  connect() {
    this.initializeChart()
    this.renderChart()
  }

  initializeChart() {
    this.startDate = new Date(this.dateRangeValue.start)
    this.endDate = new Date(this.dateRangeValue.end)
    this.totalDays = Math.ceil((this.endDate - this.startDate) / (1000 * 60 * 60 * 24))
    
    // Chart dimensions
    this.chartWidth = Math.max(this.totalDays * 30, 800) // 30px per day, minimum 800px
    this.rowHeight = 50
    this.headerHeight = 80
  }

  renderChart() {
    this.renderTimeline()
    this.renderTasks()
    this.renderLegend()
    this.setupInteractions()
  }

  renderTimeline() {
    const timeline = this.timelineTarget
    timeline.innerHTML = ''
    timeline.style.width = `${this.chartWidth}px`

    // Date headers
    const datesRow = document.createElement('div')
    datesRow.className = 'gantt-dates-row'
    
    for (let i = 0; i <= this.totalDays; i++) {
      const currentDate = new Date(this.startDate)
      currentDate.setDate(currentDate.getDate() + i)
      
      const dateCell = document.createElement('div')
      dateCell.className = 'gantt-date-cell'
      dateCell.style.width = '30px'
      
      // Show every 7th day or first/last day
      if (i % 7 === 0 || i === this.totalDays) {
        dateCell.innerHTML = `
          <div class="date-label">
            <div class="month">${currentDate.toLocaleDateString('ja-JP', { month: 'short' })}</div>
            <div class="day">${currentDate.getDate()}</div>
          </div>
        `
      }
      
      // Highlight weekends
      if (currentDate.getDay() === 0 || currentDate.getDay() === 6) {
        dateCell.classList.add('weekend')
      }
      
      // Highlight today
      if (this.isSameDay(currentDate, new Date())) {
        dateCell.classList.add('today')
      }
      
      datesRow.appendChild(dateCell)
    }
    
    timeline.appendChild(datesRow)
  }

  renderTasks() {
    const tasksContainer = this.tasksTarget
    tasksContainer.innerHTML = ''
    tasksContainer.style.width = `${this.chartWidth}px`

    this.tasksValue.forEach((task, index) => {
      const taskRow = this.createTaskRow(task, index)
      tasksContainer.appendChild(taskRow)
    })
  }

  createTaskRow(task, index) {
    const row = document.createElement('div')
    row.className = 'gantt-task-row'
    row.style.height = `${this.rowHeight}px`

    // Task info panel
    const taskInfo = document.createElement('div')
    taskInfo.className = 'gantt-task-info'
    taskInfo.innerHTML = `
      <div class="task-name" title="${task.description || ''}">${task.name}</div>
      <div class="task-meta">
        <span class="priority priority-${task.priority}">${this.getPriorityText(task.priority)}</span>
        <span class="status status-${task.status}">${this.getStatusText(task.status)}</span>
        <span class="user">${task.user}</span>
      </div>
    `

    // Task bar
    const taskStart = new Date(task.start)
    const taskEnd = new Date(task.end)
    const startOffset = Math.ceil((taskStart - this.startDate) / (1000 * 60 * 60 * 24))
    const duration = Math.ceil((taskEnd - taskStart) / (1000 * 60 * 60 * 24)) + 1

    const taskBar = document.createElement('div')
    taskBar.className = 'gantt-task-bar'
    taskBar.style.left = `${startOffset * 30}px`
    taskBar.style.width = `${duration * 30}px`
    taskBar.style.backgroundColor = task.color
    taskBar.dataset.taskId = task.id

    // Progress bar
    if (task.progress > 0) {
      const progressBar = document.createElement('div')
      progressBar.className = 'gantt-progress-bar'
      progressBar.style.width = `${task.progress}%`
      taskBar.appendChild(progressBar)
    }

    // Task bar content
    const barContent = document.createElement('div')
    barContent.className = 'gantt-bar-content'
    barContent.textContent = task.name
    taskBar.appendChild(barContent)

    // Warning indicators
    if (task.overdue) {
      taskBar.classList.add('overdue')
      const warning = document.createElement('i')
      warning.className = 'bi bi-exclamation-triangle-fill text-white'
      warning.style.marginLeft = '5px'
      barContent.appendChild(warning)
    } else if (task.due_soon) {
      taskBar.classList.add('due-soon')
      const warning = document.createElement('i')
      warning.className = 'bi bi-clock-fill text-white'
      warning.style.marginLeft = '5px'
      barContent.appendChild(warning)
    }

    row.appendChild(taskBar)
    return row
  }

  renderLegend() {
    const legend = this.legendTarget
    legend.innerHTML = `
      <div class="gantt-legend">
        <h6>優先度</h6>
        <div class="legend-items">
          <div class="legend-item">
            <div class="legend-color" style="background-color: #e74c3c"></div>
            <span>緊急</span>
          </div>
          <div class="legend-item">
            <div class="legend-color" style="background-color: #f39c12"></div>
            <span>高</span>
          </div>
          <div class="legend-item">
            <div class="legend-color" style="background-color: #3498db"></div>
            <span>中</span>
          </div>
          <div class="legend-item">
            <div class="legend-color" style="background-color: #27ae60"></div>
            <span>低</span>
          </div>
        </div>
        
        <h6 class="mt-3">ステータス</h6>
        <div class="legend-items">
          <div class="legend-item">
            <i class="bi bi-circle text-secondary"></i>
            <span>未着手</span>
          </div>
          <div class="legend-item">
            <i class="bi bi-play-circle text-primary"></i>
            <span>進行中</span>
          </div>
          <div class="legend-item">
            <i class="bi bi-check-circle text-success"></i>
            <span>完了</span>
          </div>
          <div class="legend-item">
            <i class="bi bi-x-circle text-danger"></i>
            <span>キャンセル</span>
          </div>
        </div>
        
        <h6 class="mt-3">警告</h6>
        <div class="legend-items">
          <div class="legend-item">
            <i class="bi bi-exclamation-triangle-fill text-danger"></i>
            <span>期限切れ</span>
          </div>
          <div class="legend-item">
            <i class="bi bi-clock-fill text-warning"></i>
            <span>期限間近</span>
          </div>
        </div>
      </div>
    `
  }

  setupInteractions() {
    // Task bar click events
    this.tasksTarget.addEventListener('click', (event) => {
      const taskBar = event.target.closest('.gantt-task-bar')
      if (taskBar) {
        const taskId = taskBar.dataset.taskId
        this.showTaskDetails(taskId)
      }
    })

    // Horizontal scroll synchronization
    this.chartTarget.addEventListener('scroll', (event) => {
      this.timelineTarget.scrollLeft = event.target.scrollLeft
    })
  }

  showTaskDetails(taskId) {
    const task = this.tasksValue.find(t => t.id.toString() === taskId)
    if (task) {
      // Create modal or tooltip with task details
      alert(`タスク: ${task.name}\n期間: ${task.start} ～ ${task.end}\n担当者: ${task.user}\n進捗: ${task.progress}%\n説明: ${task.description || 'なし'}`)
    }
  }

  getPriorityText(priority) {
    const priorities = {
      'urgent': '緊急',
      'high': '高',
      'medium': '中',
      'low': '低'
    }
    return priorities[priority] || priority
  }

  getStatusText(status) {
    const statuses = {
      'pending': '未着手',
      'in_progress': '進行中',
      'completed': '完了',
      'cancelled': 'キャンセル'
    }
    return statuses[status] || status
  }

  isSameDay(date1, date2) {
    return date1.getFullYear() === date2.getFullYear() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getDate() === date2.getDate()
  }

  // Filter tasks by status
  filterByStatus(event) {
    const status = event.target.value
    this.filterTasks({ status })
  }

  // Filter tasks by priority
  filterByPriority(event) {
    const priority = event.target.value
    this.filterTasks({ priority })
  }

  filterTasks(filters) {
    let filteredTasks = [...this.tasksValue]

    if (filters.status && filters.status !== 'all') {
      filteredTasks = filteredTasks.filter(task => task.status === filters.status)
    }

    if (filters.priority && filters.priority !== 'all') {
      filteredTasks = filteredTasks.filter(task => task.priority === filters.priority)
    }

    // Re-render with filtered tasks
    this.tasksValue = filteredTasks
    this.renderTasks()
  }

  // Zoom functionality
  zoomIn() {
    this.chartWidth = Math.min(this.chartWidth * 1.2, this.totalDays * 60)
    this.updateChartWidth()
  }

  zoomOut() {
    this.chartWidth = Math.max(this.chartWidth * 0.8, this.totalDays * 15)
    this.updateChartWidth()
  }

  updateChartWidth() {
    this.timelineTarget.style.width = `${this.chartWidth}px`
    this.tasksTarget.style.width = `${this.chartWidth}px`
    this.renderTimeline()
    this.renderTasks()
  }
}