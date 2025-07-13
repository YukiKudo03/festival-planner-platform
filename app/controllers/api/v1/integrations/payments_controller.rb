class Api::V1::Integrations::PaymentsController < Api::V1::BaseController
  before_action :set_payment_integration, only: [:show, :update, :destroy, :process_payment, 
                                                  :create_refund, :test_connection, :analytics]

  # GET /api/v1/integrations/payments
  def index
    integrations = current_user.payment_integrations.includes(:festival)
    integrations = integrations.where(festival_id: params[:festival_id]) if params[:festival_id]
    integrations = integrations.where(provider: params[:provider]) if params[:provider]
    integrations = integrations.where(active: true) if params[:active] == 'true'
    
    render json: {
      integrations: integrations.map { |integration| serialize_integration(integration) }
    }
  end

  # GET /api/v1/integrations/payments/:id
  def show
    render json: {
      integration: serialize_integration_detailed(@integration)
    }
  end

  # POST /api/v1/integrations/payments
  def create
    @integration = current_user.payment_integrations.build(integration_params)
    
    if @integration.save
      # Test the connection
      test_result = test_payment_connection(@integration)
      
      if test_result[:success]
        @integration.update(status: :connected)
        
        render json: {
          integration: serialize_integration_detailed(@integration),
          message: 'Payment integration created successfully',
          connection_test: test_result
        }, status: :created
      else
        @integration.update(status: :error, last_error: test_result[:message])
        
        render json: {
          integration: serialize_integration_detailed(@integration),
          message: 'Payment integration created but connection failed',
          connection_test: test_result
        }, status: :created
      end
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/integrations/payments/:id
  def update
    if @integration.update(integration_params)
      render json: {
        integration: serialize_integration_detailed(@integration),
        message: 'Payment integration updated successfully'
      }
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/integrations/payments/:id
  def destroy
    @integration.destroy
    render json: {
      message: 'Payment integration deleted successfully'
    }
  end

  # POST /api/v1/integrations/payments/:id/process_payment
  def process_payment
    unless @integration.payment_enabled?
      return render json: {
        error: 'Payment integration is not enabled',
        details: 'Please check integration status and credentials'
      }, status: :unprocessable_entity
    end

    result = @integration.process_payment!(
      payment_params[:amount],
      payment_params.except(:amount).to_h.symbolize_keys
    )

    if result[:success]
      render json: {
        payment: result,
        integration: serialize_integration(@integration),
        message: 'Payment processed successfully'
      }
    else
      render json: {
        error: 'Payment processing failed',
        details: result[:error],
        integration: serialize_integration(@integration)
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/payments/:id/create_payment_intent
  def create_payment_intent
    unless @integration.payment_enabled?
      return render json: {
        error: 'Payment integration is not enabled'
      }, status: :unprocessable_entity
    end

    result = @integration.create_payment_intent(
      payment_intent_params[:amount],
      payment_intent_params.except(:amount).to_h.symbolize_keys
    )

    if result[:success]
      render json: {
        payment_intent: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Failed to create payment intent',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/payments/:id/refund
  def create_refund
    unless @integration.supports_refunds?
      return render json: {
        error: 'Refunds are not supported for this payment provider'
      }, status: :unprocessable_entity
    end

    result = @integration.create_refund!(
      refund_params[:transaction_id],
      refund_params[:amount],
      refund_params[:reason]
    )

    if result[:success]
      render json: {
        refund: result,
        integration: serialize_integration(@integration),
        message: 'Refund processed successfully'
      }
    else
      render json: {
        error: 'Refund processing failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/payments/:id/payment_methods
  def payment_methods
    methods = @integration.get_payment_methods

    render json: {
      payment_methods: methods,
      integration: serialize_integration(@integration)
    }
  end

  # POST /api/v1/integrations/payments/:id/test_connection
  def test_connection
    result = test_payment_connection(@integration)
    
    if result[:success]
      @integration.update(status: :connected, last_error: nil)
    else
      @integration.update(status: :error, last_error: result[:message])
    end
    
    render json: {
      connection_test: result,
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/payments/:id/analytics
  def analytics
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Time.current
    
    analytics = @integration.analytics_summary(start_date, end_date)
    
    render json: {
      analytics: analytics,
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/payments/:id/transactions
  def transactions
    transactions = @integration.payment_transactions
                              .includes(:user, :festival)
                              .order(created_at: :desc)
    
    # Apply filters
    transactions = transactions.where(status: params[:status]) if params[:status]
    transactions = transactions.where('created_at >= ?', params[:start_date]) if params[:start_date]
    transactions = transactions.where('created_at <= ?', params[:end_date]) if params[:end_date]
    
    # Pagination
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    transactions = transactions.page(page).per(per_page)
    
    render json: {
      transactions: transactions.map { |transaction| serialize_transaction(transaction) },
      pagination: {
        current_page: transactions.current_page,
        total_pages: transactions.total_pages,
        total_count: transactions.total_count,
        per_page: per_page
      },
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/payments/:id/transaction/:transaction_id
  def transaction_details
    transaction = @integration.payment_transactions.find_by(
      transaction_id: params[:transaction_id]
    )
    
    unless transaction
      return render json: {
        error: 'Transaction not found'
      }, status: :not_found
    end

    # Get detailed information from payment provider
    provider_details = @integration.payment_service.get_transaction_details(
      params[:transaction_id]
    ) if @integration.payment_enabled?

    render json: {
      transaction: serialize_transaction_detailed(transaction),
      provider_details: provider_details,
      integration: serialize_integration(@integration)
    }
  end

  # POST /api/v1/integrations/payments/:id/setup_webhooks
  def setup_webhooks
    unless @integration.supports_webhooks?
      return render json: {
        error: 'Webhooks are not supported for this payment provider'
      }, status: :unprocessable_entity
    end

    success = @integration.setup_webhooks!
    
    if success
      render json: {
        message: 'Webhooks set up successfully',
        webhook_url: @integration.webhook_url,
        integration: serialize_integration_detailed(@integration)
      }
    else
      render json: {
        error: 'Failed to set up webhooks',
        details: @integration.last_error
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/payments/providers
  def providers
    render json: {
      providers: [
        {
          id: 'stripe',
          name: 'Stripe',
          description: 'Online payment processing for internet businesses',
          features: ['cards', 'subscriptions', 'refunds', 'webhooks', 'international'],
          currencies: ['USD', 'EUR', 'JPY', 'GBP', 'AUD', 'CAD'],
          fees: {
            card_processing: '2.9% + 30¢',
            international: '3.9% + 30¢'
          },
          setup_requirements: ['api_key', 'webhook_secret']
        },
        {
          id: 'square',
          name: 'Square',
          description: 'Payment processing for businesses of all sizes',
          features: ['cards', 'in_person', 'subscriptions', 'refunds', 'webhooks'],
          currencies: ['USD', 'CAD', 'GBP', 'AUD', 'JPY'],
          fees: {
            card_processing: '2.6% + 10¢',
            in_person: '2.6%'
          },
          setup_requirements: ['access_token', 'location_id']
        },
        {
          id: 'paypal',
          name: 'PayPal',
          description: 'Global online payment system',
          features: ['paypal_account', 'cards', 'subscriptions', 'refunds', 'international'],
          currencies: ['USD', 'EUR', 'JPY', 'GBP', 'AUD', 'CAD', 'SGD'],
          fees: {
            domestic: '2.9% + fixed_fee',
            international: '4.4% + fixed_fee'
          },
          setup_requirements: ['client_id', 'client_secret']
        },
        {
          id: 'bank_transfer',
          name: 'Bank Transfer',
          description: 'Direct bank transfer payments',
          features: ['bank_transfer', 'low_fees'],
          currencies: ['JPY'],
          fees: {
            transfer: 'Variable by bank'
          },
          setup_requirements: ['bank_account_details']
        }
      ]
    }
  end

  private

  def set_payment_integration
    @integration = current_user.payment_integrations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Payment integration not found' }, status: :not_found
  end

  def integration_params
    params.require(:payment_integration).permit(
      :name, :provider, :festival_id, :active, :account_id,
      :api_key, :api_secret, :webhook_secret, :environment,
      :location_id, :stripe_customer_id, :transaction_fee_type,
      :transaction_fee_rate, :transaction_fee_fixed, :currency
    )
  end

  def payment_params
    params.require(:payment).permit(
      :amount, :currency, :payment_method, :customer_id, :description,
      :receipt_email, :save_payment_method, customer_info: {},
      metadata: {}, billing_address: {}, shipping_address: {}
    )
  end

  def payment_intent_params
    params.require(:payment_intent).permit(
      :amount, :currency, :customer_id, :description,
      metadata: {}
    )
  end

  def refund_params
    params.require(:refund).permit(:transaction_id, :amount, :reason)
  end

  def serialize_integration(integration)
    {
      id: integration.id,
      name: integration.name,
      provider: integration.provider,
      active: integration.active,
      status: integration.status,
      account_id: integration.account_id,
      currency: integration.currency,
      transaction_fee_type: integration.transaction_fee_type,
      transaction_fee_rate: integration.transaction_fee_rate,
      supports_refunds: integration.supports_refunds?,
      supports_subscriptions: integration.supports_subscriptions?,
      supports_webhooks: integration.supports_webhooks?,
      festival: integration.festival ? {
        id: integration.festival.id,
        name: integration.festival.name
      } : nil,
      created_at: integration.created_at.iso8601
    }
  end

  def serialize_integration_detailed(integration)
    serialize_integration(integration).merge(
      environment: integration.environment,
      location_id: integration.location_id,
      transaction_fee_fixed: integration.transaction_fee_fixed,
      last_error: integration.last_error,
      webhook_url: integration.webhook_url,
      webhook_id: integration.webhook_id,
      updated_at: integration.updated_at.iso8601
    )
  end

  def serialize_transaction(transaction)
    {
      id: transaction.id,
      transaction_id: transaction.transaction_id,
      amount: transaction.amount,
      currency: transaction.currency,
      status: transaction.status,
      payment_method: transaction.payment_method,
      created_at: transaction.created_at.iso8601,
      festival: transaction.festival ? {
        id: transaction.festival.id,
        name: transaction.festival.name
      } : nil
    }
  end

  def serialize_transaction_detailed(transaction)
    serialize_transaction(transaction).merge(
      refund_amount: transaction.refund_amount,
      refund_reason: transaction.refund_reason,
      error_message: transaction.error_message,
      customer_info: transaction.customer_info,
      metadata: transaction.metadata,
      updated_at: transaction.updated_at.iso8601
    )
  end

  def test_payment_connection(integration)
    integration.test_connection
  rescue => error
    { success: false, message: error.message }
  end
end