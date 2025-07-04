import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "budgetChart", "taskChart", "vendorChart", "communicationChart",
    "budgetAnalytics", "taskAnalytics", "vendorAnalytics", "communicationAnalytics",
    "recommendations", "totalRevenue", "totalVendors", "completionRate", "budgetUtilization"
  ]
  
  static values = {
    festivalId: Number,
    autoRefresh: Boolean
  }
  
  connect() {
    this.charts = {}
    this.refreshInterval = null
    
    // Chart.jsが利用可能になるまで待機
    this.waitForChartJS().then(() => {
      this.initializeCharts()
    })
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
    
    // リアルタイムデータ更新の設定
    this.setupRealtimeUpdates()
  }
  
  disconnect() {
    this.stopAutoRefresh()
    this.destroyCharts()
  }
  
  async waitForChartJS() {
    return new Promise((resolve) => {
      if (typeof Chart !== 'undefined') {
        resolve()
      } else {
        const checkChart = () => {
          if (typeof Chart !== 'undefined') {
            resolve()
          } else {
            setTimeout(checkChart, 100)
          }
        }
        checkChart()
      }
    })
  }
  
  initializeCharts() {
    // 予算チャートの初期化
    if (this.hasBudgetChartTarget) {
      this.initializeBudgetChart()
    }
    
    // タスクチャートの初期化
    if (this.hasTaskChartTarget) {
      this.initializeTaskChart()
    }
    
    // その他のチャートも同様に初期化
    this.setupChartInteractions()
  }
  
  initializeBudgetChart() {
    const ctx = this.budgetChartTarget.getContext('2d')
    const data = JSON.parse(this.budgetChartTarget.dataset.chartData || '[]')
    
    this.charts.budget = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: data.map(item => item.name),
        datasets: [{
          data: data.map(item => item.spent),
          backgroundColor: [
            '#0d6efd', '#6610f2', '#6f42c1', '#d63384',
            '#dc3545', '#fd7e14', '#ffc107', '#198754',
            '#20c997', '#0dcaf0'
          ],
          borderWidth: 2,
          borderColor: '#ffffff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              padding: 20,
              usePointStyle: true
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const label = context.label || ''
                const value = context.parsed
                const total = context.dataset.data.reduce((a, b) => a + b, 0)
                const percentage = ((value / total) * 100).toFixed(1)
                return `${label}: ¥${value.toLocaleString()} (${percentage}%)`
              }
            }
          }
        },
        animation: {
          animateRotate: true,
          duration: 1000
        }
      }
    })
  }
  
  initializeTaskChart() {
    const ctx = this.taskChartTarget.getContext('2d')
    const data = JSON.parse(this.taskChartTarget.dataset.chartData || '{}')
    
    // データを時系列形式に変換
    const dates = Object.keys(data).sort()
    const completedData = dates.map(date => data[date]?.completed || 0)
    const inProgressData = dates.map(date => data[date]?.in_progress || 0)
    const pendingData = dates.map(date => data[date]?.pending || 0)
    
    this.charts.task = new Chart(ctx, {
      type: 'line',
      data: {
        labels: dates.map(date => new Date(date).toLocaleDateString('ja-JP')),
        datasets: [
          {
            label: '完了',
            data: completedData,
            borderColor: '#198754',
            backgroundColor: 'rgba(25, 135, 84, 0.1)',
            fill: true,
            tension: 0.4
          },
          {
            label: '進行中',
            data: inProgressData,
            borderColor: '#ffc107',
            backgroundColor: 'rgba(255, 193, 7, 0.1)',
            fill: true,
            tension: 0.4
          },
          {
            label: '未着手',
            data: pendingData,
            borderColor: '#6c757d',
            backgroundColor: 'rgba(108, 117, 125, 0.1)',
            fill: true,
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              stepSize: 1
            }
          }
        },
        plugins: {
          legend: {
            position: 'top'
          },
          tooltip: {
            mode: 'index',
            intersect: false
          }
        },
        hover: {
          mode: 'nearest',
          intersect: true
        },
        animation: {
          duration: 1000,
          easing: 'easeOutQuart'
        }
      }
    })
  }
  
  setupChartInteractions() {
    // チャートのクリックイベント設定
    Object.values(this.charts).forEach(chart => {
      chart.canvas.addEventListener('click', (event) => {
        const points = chart.getElementsAtEventForMode(event, 'nearest', { intersect: true }, true)
        if (points.length) {
          const point = points[0]
          this.handleChartClick(chart, point)
        }
      })
    })
  }
  
  handleChartClick(chart, point) {
    // チャートのクリック時の詳細表示処理
    const datasetIndex = point.datasetIndex
    const index = point.index
    
    console.log('Chart clicked:', {
      chart: chart.config.type,
      datasetIndex,
      index,
      value: chart.data.datasets[datasetIndex].data[index]
    })
    
    // 詳細表示モーダルの表示など
    this.showDetailModal(chart, point)
  }
  
  showDetailModal(chart, point) {
    // 詳細情報表示モーダルの実装
    // 将来的にBootstrapモーダルで詳細データを表示
  }
  
  refresh() {
    this.showLoadingState()
    
    fetch(`/admin/festivals/${this.festivalIdValue}/dashboard.json`)
      .then(response => response.json())
      .then(data => this.updateDashboard(data))
      .catch(error => {
        console.error('Dashboard refresh failed:', error)
        this.showError('データの更新に失敗しました')
      })
      .finally(() => {
        this.hideLoadingState()
      })
  }
  
  updateDashboard(data) {
    // メトリクス値の更新
    this.updateMetrics(data.overview)
    
    // チャートデータの更新
    this.updateCharts(data)
    
    // アナリティクスセクションの更新
    this.updateAnalyticsSections(data)
    
    // 成功メッセージの表示
    this.showSuccess('ダッシュボードを更新しました')
  }
  
  updateMetrics(overview) {
    if (this.hasTotalRevenueTarget) {
      this.totalRevenueTarget.textContent = `¥${overview.total_revenue.toLocaleString()}`
    }
    
    if (this.hasTotalVendorsTarget) {
      this.totalVendorsTarget.textContent = overview.total_vendors
    }
    
    if (this.hasCompletionRateTarget) {
      this.completionRateTarget.textContent = `${overview.completion_rate}%`
    }
    
    if (this.hasBudgetUtilizationTarget) {
      this.budgetUtilizationTarget.textContent = `${overview.budget_utilization}%`
    }
  }
  
  updateCharts(data) {
    // 予算チャートの更新
    if (this.charts.budget && data.budget_analytics) {
      this.updateBudgetChart(data.budget_analytics.expense_breakdown)
    }
    
    // タスクチャートの更新
    if (this.charts.task && data.task_analytics) {
      this.updateTaskChart(data.task_analytics.completion_trends)
    }
  }
  
  updateBudgetChart(expenseData) {
    const chart = this.charts.budget
    chart.data.labels = expenseData.map(item => item.name)
    chart.data.datasets[0].data = expenseData.map(item => item.spent)
    chart.update('active')
  }
  
  updateTaskChart(completionData) {
    const chart = this.charts.task
    const dates = Object.keys(completionData).sort()
    
    chart.data.labels = dates.map(date => new Date(date).toLocaleDateString('ja-JP'))
    chart.data.datasets[0].data = dates.map(date => completionData[date]?.completed || 0)
    chart.data.datasets[1].data = dates.map(date => completionData[date]?.in_progress || 0)
    chart.data.datasets[2].data = dates.map(date => completionData[date]?.pending || 0)
    chart.update('active')
  }
  
  updateAnalyticsSections(data) {
    // 各アナリティクスセクションの非同期更新
    const sections = [
      { target: 'budgetAnalytics', url: `/admin/festivals/${this.festivalIdValue}/dashboard/budget_analytics` },
      { target: 'taskAnalytics', url: `/admin/festivals/${this.festivalIdValue}/dashboard/task_analytics` },
      { target: 'vendorAnalytics', url: `/admin/festivals/${this.festivalIdValue}/dashboard/vendor_analytics` },
      { target: 'communicationAnalytics', url: `/admin/festivals/${this.festivalIdValue}/dashboard/communication_analytics` }
    ]
    
    sections.forEach(section => {
      if (this.hasTarget(section.target)) {
        this.updateSection(section.target, section.url)
      }
    })
  }
  
  updateSection(targetName, url) {
    const target = this[`${targetName}Target`]
    if (!target) return
    
    fetch(url)
      .then(response => response.text())
      .then(html => {
        target.innerHTML = html
      })
      .catch(error => {
        console.error(`Failed to update ${targetName}:`, error)
      })
  }
  
  startAutoRefresh() {
    this.refreshInterval = setInterval(() => {
      this.refresh()
    }, 300000) // 5分ごとに更新
  }
  
  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
      this.refreshInterval = null
    }
  }
  
  setupRealtimeUpdates() {
    // ActionCableを使用したリアルタイム更新
    // 将来的にWebSocketでリアルタイム更新を実装
  }
  
  destroyCharts() {
    Object.values(this.charts).forEach(chart => {
      if (chart) {
        chart.destroy()
      }
    })
    this.charts = {}
  }
  
  showLoadingState() {
    // ローディング状態の表示
    const loadingHtml = `
      <div class="loading-spinner">
        <div class="spinner-border text-primary" role="status">
          <span class="visually-hidden">読み込み中...</span>
        </div>
      </div>
    `
    
    // 各セクションにローディング表示
    ['budgetAnalytics', 'taskAnalytics', 'vendorAnalytics', 'communicationAnalytics'].forEach(targetName => {
      if (this.hasTarget(targetName)) {
        this[`${targetName}Target`].innerHTML = loadingHtml
      }
    })
  }
  
  hideLoadingState() {
    // ローディング状態の非表示は updateDashboard で処理される
  }
  
  showSuccess(message) {
    this.showToast(message, 'success')
  }
  
  showError(message) {
    this.showToast(message, 'error')
  }
  
  showToast(message, type) {
    // Bootstrap Toast を使用した通知表示
    const toastHtml = `
      <div class="toast align-items-center text-white bg-${type === 'success' ? 'success' : 'danger'} border-0" role="alert">
        <div class="d-flex">
          <div class="toast-body">
            ${message}
          </div>
          <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
        </div>
      </div>
    `
    
    // トーストコンテナがない場合は作成
    let toastContainer = document.querySelector('.toast-container')
    if (!toastContainer) {
      toastContainer = document.createElement('div')
      toastContainer.className = 'toast-container position-fixed top-0 end-0 p-3'
      document.body.appendChild(toastContainer)
    }
    
    const toastElement = document.createElement('div')
    toastElement.innerHTML = toastHtml
    toastContainer.appendChild(toastElement.firstElementChild)
    
    const toast = new bootstrap.Toast(toastElement.firstElementChild)
    toast.show()
    
    // トースト削除
    setTimeout(() => {
      toastElement.firstElementChild.remove()
    }, 5000)
  }
}