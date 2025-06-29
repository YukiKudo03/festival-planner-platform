// Bootstrap form validation
document.addEventListener('DOMContentLoaded', function() {
  // Fetch all the forms we want to apply custom Bootstrap validation styles to
  const forms = document.querySelectorAll('.needs-validation');

  // Loop over them and prevent submission
  Array.from(forms).forEach(form => {
    form.addEventListener('submit', event => {
      if (!form.checkValidity()) {
        event.preventDefault();
        event.stopPropagation();
      }

      form.classList.add('was-validated');
    }, false);
  });

  // Custom validation for password confirmation
  const passwordField = document.getElementById('user_password');
  const passwordConfirmationField = document.getElementById('user_password_confirmation');
  
  if (passwordField && passwordConfirmationField) {
    const validatePasswordMatch = () => {
      if (passwordField.value !== passwordConfirmationField.value) {
        passwordConfirmationField.setCustomValidity('パスワードが一致しません');
      } else {
        passwordConfirmationField.setCustomValidity('');
      }
    };

    passwordField.addEventListener('input', validatePasswordMatch);
    passwordConfirmationField.addEventListener('input', validatePasswordMatch);
  }

  // Phone number validation
  const phoneFields = document.querySelectorAll('input[type="tel"], input[name*="phone"]');
  phoneFields.forEach(field => {
    field.addEventListener('input', function() {
      const phonePattern = /^[\d\-\(\)\+\s]*$/;
      if (this.value && !phonePattern.test(this.value)) {
        this.setCustomValidity('有効な電話番号を入力してください（数字、ハイフン、括弧、スペースのみ）');
      } else {
        this.setCustomValidity('');
      }
    });
  });

  // Date validation for festivals
  const startDateField = document.getElementById('festival_start_date');
  const endDateField = document.getElementById('festival_end_date');
  
  if (startDateField && endDateField) {
    const validateDateRange = () => {
      if (startDateField.value && endDateField.value) {
        const startDate = new Date(startDateField.value);
        const endDate = new Date(endDateField.value);
        
        if (endDate <= startDate) {
          endDateField.setCustomValidity('終了日時は開始日時より後に設定してください');
        } else {
          endDateField.setCustomValidity('');
        }
      }
    };

    startDateField.addEventListener('change', validateDateRange);
    endDateField.addEventListener('change', validateDateRange);
  }

  // Task due date validation
  const taskDueDateField = document.getElementById('task_due_date');
  if (taskDueDateField) {
    taskDueDateField.addEventListener('change', function() {
      const dueDate = new Date(this.value);
      const now = new Date();
      
      if (dueDate < now) {
        // Allow past dates but show warning
        this.classList.add('border-warning');
        this.setAttribute('title', '過去の日時が設定されています');
      } else {
        this.classList.remove('border-warning');
        this.removeAttribute('title');
      }
    });
  }

  // Real-time character count for text areas
  const textAreas = document.querySelectorAll('textarea[maxlength]');
  textAreas.forEach(textArea => {
    const maxLength = textArea.getAttribute('maxlength');
    const counter = document.createElement('div');
    counter.className = 'form-text text-end';
    counter.style.fontSize = '0.875rem';
    textArea.parentNode.appendChild(counter);

    const updateCounter = () => {
      const remaining = maxLength - textArea.value.length;
      counter.textContent = `残り${remaining}文字`;
      
      if (remaining < 50) {
        counter.className = 'form-text text-end text-warning';
      } else if (remaining < 0) {
        counter.className = 'form-text text-end text-danger';
      } else {
        counter.className = 'form-text text-end text-muted';
      }
    };

    textArea.addEventListener('input', updateCounter);
    updateCounter(); // Initial count
  });
});

// Export for use in other modules
export { };