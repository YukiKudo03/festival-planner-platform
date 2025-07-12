// Mobile Optimization JavaScript for Festival Planner Platform

class MobileOptimization {
  constructor() {
    this.init();
  }

  init() {
    this.detectMobile();
    this.setupTouchOptimizations();
    this.setupMobileNavigation();
    this.setupMobileTables();
    this.setupMobileForms();
    this.setupMobileModals();
    this.setupSwipeGestures();
    this.setupVirtualKeyboard();
    this.setupPullToRefresh();
    this.setupOfflineSupport();
    this.setupPerformanceOptimizations();
  }

  detectMobile() {
    this.isMobile = window.innerWidth <= 768;
    this.isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    this.isAndroid = /Android/.test(navigator.userAgent);
    
    document.body.classList.toggle('mobile-device', this.isMobile);
    document.body.classList.toggle('touch-device', this.isTouch);
    document.body.classList.toggle('ios-device', this.isIOS);
    document.body.classList.toggle('android-device', this.isAndroid);

    // Handle orientation changes
    window.addEventListener('orientationchange', () => {
      setTimeout(() => {
        this.isMobile = window.innerWidth <= 768;
        document.body.classList.toggle('mobile-device', this.isMobile);
        this.handleOrientationChange();
      }, 100);
    });
  }

  setupTouchOptimizations() {
    if (!this.isTouch) return;

    // Add touch-optimized class to body
    document.body.classList.add('touch-optimized');

    // Improve touch responsiveness
    document.addEventListener('touchstart', () => {}, { passive: true });

    // Handle double tap to zoom prevention
    let lastTouchEnd = 0;
    document.addEventListener('touchend', (event) => {
      const now = (new Date()).getTime();
      if (now - lastTouchEnd <= 300) {
        event.preventDefault();
      }
      lastTouchEnd = now;
    }, false);

    // Fast click implementation
    this.setupFastClick();
  }

  setupFastClick() {
    // Custom fast click implementation for better touch response
    let touchStartX, touchStartY, touchStartTime;

    document.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      touchStartX = touch.clientX;
      touchStartY = touch.clientY;
      touchStartTime = Date.now();
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
      if (e.touches.length > 0) return;

      const touch = e.changedTouches[0];
      const touchEndX = touch.clientX;
      const touchEndY = touch.clientY;
      const touchEndTime = Date.now();

      const deltaX = Math.abs(touchEndX - touchStartX);
      const deltaY = Math.abs(touchEndY - touchStartY);
      const deltaTime = touchEndTime - touchStartTime;

      // If it's a tap (not a swipe) and quick
      if (deltaX < 10 && deltaY < 10 && deltaTime < 300) {
        const target = document.elementFromPoint(touchEndX, touchEndY);
        if (target && (target.tagName === 'BUTTON' || target.tagName === 'A' || target.closest('button, a'))) {
          e.preventDefault();
          const event = new CustomEvent('fastclick', { bubbles: true });
          target.dispatchEvent(event);
        }
      }
    }, { passive: false });

    // Handle fast click events
    document.addEventListener('fastclick', (e) => {
      const target = e.target.closest('button, a, [role="button"]');
      if (target) {
        target.click();
      }
    });
  }

  setupMobileNavigation() {
    const navbar = document.querySelector('.navbar');
    const navbarToggler = document.querySelector('.navbar-toggler');
    const navbarCollapse = document.querySelector('.navbar-collapse');

    if (!navbar || !this.isMobile) return;

    navbar.classList.add('mobile-navigation');

    // Improved mobile menu toggle
    if (navbarToggler && navbarCollapse) {
      navbarToggler.addEventListener('click', () => {
        const isExpanded = navbarToggler.getAttribute('aria-expanded') === 'true';
        
        if (isExpanded) {
          navbarCollapse.style.maxHeight = '0';
          setTimeout(() => {
            navbarCollapse.classList.remove('show');
          }, 300);
        } else {
          navbarCollapse.classList.add('show');
          navbarCollapse.style.maxHeight = navbarCollapse.scrollHeight + 'px';
        }
        
        navbarToggler.setAttribute('aria-expanded', !isExpanded);
      });

      // Close menu when clicking outside
      document.addEventListener('click', (e) => {
        if (!navbar.contains(e.target) && navbarCollapse.classList.contains('show')) {
          navbarToggler.click();
        }
      });
    }

    // Handle dropdown menus in mobile
    const dropdowns = navbar.querySelectorAll('.dropdown');
    dropdowns.forEach(dropdown => {
      const toggle = dropdown.querySelector('.dropdown-toggle');
      const menu = dropdown.querySelector('.dropdown-menu');

      if (toggle && menu) {
        toggle.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          
          const isOpen = menu.classList.contains('show');
          
          // Close all other dropdowns
          dropdowns.forEach(otherDropdown => {
            if (otherDropdown !== dropdown) {
              otherDropdown.querySelector('.dropdown-menu').classList.remove('show');
            }
          });
          
          menu.classList.toggle('show', !isOpen);
        });
      }
    });
  }

  setupMobileTables() {
    if (!this.isMobile) return;

    const tables = document.querySelectorAll('.table');
    tables.forEach(table => {
      const wrapper = table.closest('.table-responsive');
      if (wrapper) {
        wrapper.classList.add('mobile-table');
        
        // Add data labels for mobile stacked layout
        const headers = table.querySelectorAll('thead th');
        const rows = table.querySelectorAll('tbody tr');
        
        rows.forEach(row => {
          const cells = row.querySelectorAll('td');
          cells.forEach((cell, index) => {
            if (headers[index]) {
              cell.setAttribute('data-label', headers[index].textContent.trim());
            }
          });
        });
      }
    });
  }

  setupMobileForms() {
    if (!this.isMobile) return;

    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
      form.classList.add('mobile-form');
      
      // Improve form input experience
      const inputs = form.querySelectorAll('input, select, textarea');
      inputs.forEach(input => {
        // Add autocomplete attributes for better mobile experience
        if (input.type === 'email' && !input.autocomplete) {
          input.autocomplete = 'email';
        }
        if (input.type === 'tel' && !input.autocomplete) {
          input.autocomplete = 'tel';
        }
        if (input.name && input.name.includes('name') && !input.autocomplete) {
          input.autocomplete = 'name';
        }

        // Handle virtual keyboard
        input.addEventListener('focus', () => {
          this.handleVirtualKeyboardOpen(input);
        });

        input.addEventListener('blur', () => {
          this.handleVirtualKeyboardClose();
        });
      });

      // Group form buttons for mobile
      const submitButtons = form.querySelectorAll('button[type="submit"], input[type="submit"]');
      const resetButtons = form.querySelectorAll('button[type="reset"], input[type="reset"]');
      const otherButtons = form.querySelectorAll('button:not([type="submit"]):not([type="reset"])');

      if (submitButtons.length > 0 || resetButtons.length > 0 || otherButtons.length > 0) {
        const buttonContainer = document.createElement('div');
        buttonContainer.className = 'form-actions mt-3';
        
        [...submitButtons, ...otherButtons, ...resetButtons].forEach(button => {
          if (button.parentNode) {
            buttonContainer.appendChild(button);
          }
        });
        
        form.appendChild(buttonContainer);
      }
    });
  }

  setupMobileModals() {
    if (!this.isMobile) return;

    const modals = document.querySelectorAll('.modal');
    modals.forEach(modal => {
      modal.classList.add('mobile-modal');
      
      // Make small modals fullscreen on mobile
      const modalDialog = modal.querySelector('.modal-dialog');
      if (modalDialog && !modalDialog.classList.contains('modal-lg') && !modalDialog.classList.contains('modal-xl')) {
        modalDialog.classList.add('modal-fullscreen-sm-down');
      }

      // Improve modal scrolling
      const modalBody = modal.querySelector('.modal-body');
      if (modalBody) {
        modalBody.style.webkitOverflowScrolling = 'touch';
      }
    });
  }

  setupSwipeGestures() {
    if (!this.isTouch) return;

    let startX, startY, endX, endY;

    document.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      startX = touch.clientX;
      startY = touch.clientY;
    }, { passive: true });

    document.addEventListener('touchmove', (e) => {
      if (!startX || !startY) return;
      
      const touch = e.touches[0];
      endX = touch.clientX;
      endY = touch.clientY;
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
      if (!startX || !startY || !endX || !endY) return;

      const deltaX = endX - startX;
      const deltaY = endY - startY;
      const absDeltaX = Math.abs(deltaX);
      const absDeltaY = Math.abs(deltaY);

      // Detect swipe gestures
      if (absDeltaX > absDeltaY && absDeltaX > 50) {
        if (deltaX > 0) {
          this.handleSwipeRight(e.target);
        } else {
          this.handleSwipeLeft(e.target);
        }
      } else if (absDeltaY > absDeltaX && absDeltaY > 50) {
        if (deltaY > 0) {
          this.handleSwipeDown(e.target);
        } else {
          this.handleSwipeUp(e.target);
        }
      }

      // Reset values
      startX = startY = endX = endY = null;
    }, { passive: true });
  }

  handleSwipeRight(target) {
    // Handle swipe right - could be used for navigation
    const carousel = target.closest('.carousel');
    if (carousel && bootstrap.Carousel) {
      const carouselInstance = bootstrap.Carousel.getInstance(carousel);
      if (carouselInstance) {
        carouselInstance.prev();
      }
    }

    // Custom swipe right event
    target.dispatchEvent(new CustomEvent('swiperight', { bubbles: true }));
  }

  handleSwipeLeft(target) {
    // Handle swipe left
    const carousel = target.closest('.carousel');
    if (carousel && bootstrap.Carousel) {
      const carouselInstance = bootstrap.Carousel.getInstance(carousel);
      if (carouselInstance) {
        carouselInstance.next();
      }
    }

    // Custom swipe left event
    target.dispatchEvent(new CustomEvent('swipeleft', { bubbles: true }));
  }

  handleSwipeUp(target) {
    // Handle swipe up
    target.dispatchEvent(new CustomEvent('swipeup', { bubbles: true }));
  }

  handleSwipeDown(target) {
    // Handle swipe down - could trigger pull to refresh
    target.dispatchEvent(new CustomEvent('swipedown', { bubbles: true }));
  }

  setupVirtualKeyboard() {
    if (!this.isMobile) return;

    let initialViewportHeight = window.innerHeight;
    let keyboardOpen = false;

    const handleViewportChange = () => {
      const currentHeight = window.innerHeight;
      const heightDifference = initialViewportHeight - currentHeight;
      
      if (heightDifference > 150 && !keyboardOpen) {
        // Keyboard opened
        keyboardOpen = true;
        document.body.classList.add('keyboard-open');
        this.adjustLayoutForKeyboard(true);
      } else if (heightDifference <= 150 && keyboardOpen) {
        // Keyboard closed
        keyboardOpen = false;
        document.body.classList.remove('keyboard-open');
        this.adjustLayoutForKeyboard(false);
      }
    };

    window.addEventListener('resize', handleViewportChange);
    
    // iOS specific handling
    if (this.isIOS) {
      window.addEventListener('focusin', () => {
        setTimeout(handleViewportChange, 300);
      });
      
      window.addEventListener('focusout', () => {
        setTimeout(handleViewportChange, 300);
      });
    }
  }

  handleVirtualKeyboardOpen(input) {
    // Scroll input into view
    setTimeout(() => {
      input.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 300);
  }

  handleVirtualKeyboardClose() {
    // Restore scroll position if needed
    setTimeout(() => {
      window.scrollTo(0, 0);
    }, 100);
  }

  adjustLayoutForKeyboard(keyboardOpen) {
    const fixedElements = document.querySelectorAll('.navbar-fixed-top, .navbar-fixed-bottom, .fixed-bottom');
    
    fixedElements.forEach(element => {
      if (keyboardOpen) {
        element.style.position = 'absolute';
      } else {
        element.style.position = 'fixed';
      }
    });
  }

  setupPullToRefresh() {
    if (!this.isTouch) return;

    let startY = 0;
    let pullDistance = 0;
    let isPulling = false;
    const pullThreshold = 80;

    document.addEventListener('touchstart', (e) => {
      if (window.pageYOffset === 0) {
        startY = e.touches[0].clientY;
        isPulling = true;
      }
    }, { passive: true });

    document.addEventListener('touchmove', (e) => {
      if (!isPulling) return;

      const currentY = e.touches[0].clientY;
      pullDistance = currentY - startY;

      if (pullDistance > 0 && window.pageYOffset === 0) {
        // Show pull to refresh indicator
        this.showPullToRefreshIndicator(pullDistance);
        
        if (pullDistance > pullThreshold) {
          // Change indicator to "release to refresh"
          this.updatePullToRefreshIndicator(true);
        } else {
          this.updatePullToRefreshIndicator(false);
        }
      }
    }, { passive: true });

    document.addEventListener('touchend', () => {
      if (isPulling && pullDistance > pullThreshold) {
        this.triggerRefresh();
      }
      
      this.hidePullToRefreshIndicator();
      isPulling = false;
      pullDistance = 0;
      startY = 0;
    }, { passive: true });
  }

  showPullToRefreshIndicator(distance) {
    let indicator = document.getElementById('pull-to-refresh-indicator');
    if (!indicator) {
      indicator = document.createElement('div');
      indicator.id = 'pull-to-refresh-indicator';
      indicator.innerHTML = `
        <div class="pull-indicator">
          <div class="pull-icon">↓</div>
          <div class="pull-text">Pull to refresh</div>
        </div>
      `;
      indicator.style.cssText = `
        position: fixed;
        top: -80px;
        left: 0;
        right: 0;
        height: 80px;
        background: #f8f9fa;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: transform 0.3s ease;
        z-index: 9999;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      `;
      document.body.appendChild(indicator);
    }
    
    const transform = Math.min(distance, 80);
    indicator.style.transform = `translateY(${transform}px)`;
  }

  updatePullToRefreshIndicator(releaseToRefresh) {
    const indicator = document.getElementById('pull-to-refresh-indicator');
    if (indicator) {
      const icon = indicator.querySelector('.pull-icon');
      const text = indicator.querySelector('.pull-text');
      
      if (releaseToRefresh) {
        icon.innerHTML = '↑';
        text.textContent = 'Release to refresh';
        indicator.style.background = '#d4edda';
      } else {
        icon.innerHTML = '↓';
        text.textContent = 'Pull to refresh';
        indicator.style.background = '#f8f9fa';
      }
    }
  }

  hidePullToRefreshIndicator() {
    const indicator = document.getElementById('pull-to-refresh-indicator');
    if (indicator) {
      indicator.style.transform = 'translateY(-80px)';
      setTimeout(() => {
        indicator.remove();
      }, 300);
    }
  }

  triggerRefresh() {
    // Show loading state
    this.showRefreshLoading();
    
    // Trigger custom refresh event
    document.dispatchEvent(new CustomEvent('pulltorefresh'));
    
    // Simulate refresh (in real app, this would trigger actual refresh)
    setTimeout(() => {
      this.hideRefreshLoading();
      location.reload();
    }, 1000);
  }

  showRefreshLoading() {
    const indicator = document.getElementById('pull-to-refresh-indicator');
    if (indicator) {
      indicator.innerHTML = `
        <div class="pull-indicator">
          <div class="spinner-border spinner-border-sm" role="status"></div>
          <div class="pull-text">Refreshing...</div>
        </div>
      `;
      indicator.style.background = '#d1ecf1';
    }
  }

  hideRefreshLoading() {
    this.hidePullToRefreshIndicator();
  }

  setupOfflineSupport() {
    // Basic offline detection
    const updateOnlineStatus = () => {
      const isOnline = navigator.onLine;
      document.body.classList.toggle('offline', !isOnline);
      
      if (!isOnline) {
        this.showOfflineNotification();
      } else {
        this.hideOfflineNotification();
      }
    };

    window.addEventListener('online', updateOnlineStatus);
    window.addEventListener('offline', updateOnlineStatus);
    updateOnlineStatus();
  }

  showOfflineNotification() {
    let notification = document.getElementById('offline-notification');
    if (!notification) {
      notification = document.createElement('div');
      notification.id = 'offline-notification';
      notification.innerHTML = `
        <div class="alert alert-warning mb-0" role="alert">
          <i class="fas fa-wifi-slash me-2"></i>
          You're currently offline. Some features may not be available.
        </div>
      `;
      notification.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        z-index: 9999;
        transform: translateY(-100%);
        transition: transform 0.3s ease;
      `;
      document.body.appendChild(notification);
    }
    
    setTimeout(() => {
      notification.style.transform = 'translateY(0)';
    }, 100);
  }

  hideOfflineNotification() {
    const notification = document.getElementById('offline-notification');
    if (notification) {
      notification.style.transform = 'translateY(-100%)';
      setTimeout(() => {
        notification.remove();
      }, 300);
    }
  }

  setupPerformanceOptimizations() {
    // Lazy load images on mobile
    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target;
            if (img.dataset.src) {
              img.src = img.dataset.src;
              img.removeAttribute('data-src');
              imageObserver.unobserve(img);
            }
          }
        });
      });

      document.querySelectorAll('img[data-src]').forEach(img => {
        imageObserver.observe(img);
      });
    }

    // Reduce animations on slower devices
    if (this.isMobile && 'deviceMemory' in navigator && navigator.deviceMemory < 4) {
      document.body.classList.add('reduced-motion');
    }

    // Optimize scroll performance
    let ticking = false;
    const updateScrollPosition = () => {
      // Update scroll-dependent elements
      const scrollTop = window.pageYOffset;
      document.body.style.setProperty('--scroll-top', scrollTop + 'px');
      ticking = false;
    };

    const requestScrollUpdate = () => {
      if (!ticking) {
        requestAnimationFrame(updateScrollPosition);
        ticking = true;
      }
    };

    window.addEventListener('scroll', requestScrollUpdate, { passive: true });
  }

  handleOrientationChange() {
    // Handle layout adjustments on orientation change
    const modals = document.querySelectorAll('.modal.show');
    modals.forEach(modal => {
      // Recalculate modal positioning
      const modalDialog = modal.querySelector('.modal-dialog');
      if (modalDialog) {
        modalDialog.style.transform = 'none';
        setTimeout(() => {
          modalDialog.style.transform = '';
        }, 100);
      }
    });

    // Trigger custom orientation change event
    document.dispatchEvent(new CustomEvent('mobileorientationchange', {
      detail: { width: window.innerWidth, height: window.innerHeight }
    }));
  }

  // Public API methods
  isMobileDevice() {
    return this.isMobile;
  }

  isTouchDevice() {
    return this.isTouch;
  }

  isKeyboardOpen() {
    return document.body.classList.contains('keyboard-open');
  }

  isOffline() {
    return !navigator.onLine;
  }
}

// Initialize mobile optimization when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.mobileOptimization = new MobileOptimization();
});

// Export for use in other modules
export default MobileOptimization;