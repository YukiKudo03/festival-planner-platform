require 'rails_helper'

RSpec.describe "Load Testing", type: :request do
  let(:user) { create(:user, role: :admin) }
  let(:api_token) { user.tap(&:generate_api_token!).api_token }
  let(:headers) { { 'Authorization' => "Bearer #{api_token}", 'Content-Type' => 'application/json' } }
  let(:festival) { create(:festival, user: user) }

  before(:all) do
    # Create test data for performance testing
    @test_festival = create(:festival, public: true)
    @test_users = create_list(:user, 50)
    @test_payments = create_list(:payment, 100, festival: @test_festival)
    @test_tasks = create_list(:task, 200, festival: @test_festival)
    @test_vendor_applications = create_list(:vendor_application, 75, festival: @test_festival)
  end

  after(:all) do
    # Clean up test data
    Payment.where(festival: @test_festival).delete_all
    Task.where(festival: @test_festival).delete_all
    VendorApplication.where(festival: @test_festival).delete_all
    @test_festival.destroy
    User.where(id: @test_users.map(&:id)).delete_all
  end

  describe "API Performance Tests" do
    context "concurrent festival requests" do
      it "handles multiple simultaneous festival listings" do
        start_time = Time.current
        
        threads = []
        response_times = []
        
        # Simulate 20 concurrent requests
        20.times do
          threads << Thread.new do
            request_start = Time.current
            get "/api/v1/festivals", headers: headers
            request_time = Time.current - request_start
            
            response_times << request_time
            expect(response).to have_http_status(:ok)
          end
        end
        
        threads.each(&:join)
        total_time = Time.current - start_time
        
        # Performance assertions
        expect(total_time).to be < 10.seconds
        expect(response_times.max).to be < 3.seconds
        expect(response_times.sum / response_times.length).to be < 1.second
        
        puts "Concurrent festival requests:"
        puts "  Total time: #{total_time.round(2)}s"
        puts "  Average response time: #{(response_times.sum / response_times.length).round(3)}s"
        puts "  Max response time: #{response_times.max.round(3)}s"
      end
    end

    context "payment processing load" do
      it "handles concurrent payment creation requests" do
        start_time = Time.current
        threads = []
        success_count = 0
        error_count = 0
        
        # Mock payment service to prevent actual charges
        allow(PaymentService).to receive(:process_payment).and_return({
          success: true,
          transaction_id: 'test_txn_123'
        })
        
        # Simulate 10 concurrent payment requests
        10.times do |i|
          threads << Thread.new do
            payment_data = {
              payment: {
                amount: 1000 + i,
                payment_method: 'stripe',
                description: "Load test payment #{i}",
                customer_email: user.email,
                customer_name: user.full_name
              }
            }
            
            request_start = Time.current
            post "/api/v1/festivals/#{festival.id}/payments", 
                 params: payment_data.to_json, 
                 headers: headers
            request_time = Time.current - request_start
            
            if response.status == 201
              success_count += 1
            else
              error_count += 1
            end
            
            expect(request_time).to be < 5.seconds
          end
        end
        
        threads.each(&:join)
        total_time = Time.current - start_time
        
        expect(success_count).to be >= 8 # Allow for some rate limiting
        expect(total_time).to be < 15.seconds
        
        puts "Concurrent payment processing:"
        puts "  Total time: #{total_time.round(2)}s"
        puts "  Success rate: #{(success_count.to_f / 10 * 100).round(1)}%"
      end
    end

    context "analytics dashboard load" do
      it "handles concurrent dashboard requests efficiently" do
        start_time = Time.current
        threads = []
        response_times = []
        
        # Simulate 15 concurrent dashboard requests
        15.times do
          threads << Thread.new do
            request_start = Time.current
            get "/api/v1/festivals/#{@test_festival.id}/analytics", headers: headers
            request_time = Time.current - request_start
            
            response_times << request_time
            expect(response).to have_http_status(:ok)
            
            # Verify response contains expected analytics data
            json = JSON.parse(response.body)
            expect(json['data']).to include('overview', 'budget', 'tasks', 'vendors')
          end
        end
        
        threads.each(&:join)
        total_time = Time.current - start_time
        
        expect(total_time).to be < 20.seconds
        expect(response_times.max).to be < 5.seconds
        
        puts "Concurrent analytics requests:"
        puts "  Total time: #{total_time.round(2)}s"
        puts "  Average response time: #{(response_times.sum / response_times.length).round(3)}s"
        puts "  Max response time: #{response_times.max.round(3)}s"
      end
    end
  end

  describe "Database Performance Tests" do
    context "large dataset queries" do
      it "performs efficiently with large payment datasets" do
        start_time = Time.current
        
        # Query payments with various filters
        get "/api/v1/festivals/#{@test_festival.id}/payments", 
            params: { 
              page: 1, 
              per_page: 25,
              filters: { status: 'completed' }.to_json 
            }, 
            headers: headers
        
        query_time = Time.current - start_time
        
        expect(response).to have_http_status(:ok)
        expect(query_time).to be < 2.seconds
        
        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['meta']).to include('current_page', 'total_pages')
        
        puts "Large dataset query time: #{query_time.round(3)}s"
      end

      it "handles complex aggregation queries efficiently" do
        start_time = Time.current
        
        get "/api/v1/festivals/#{@test_festival.id}/payments/summary", headers: headers
        
        query_time = Time.current - start_time
        
        expect(response).to have_http_status(:ok)
        expect(query_time).to be < 3.seconds
        
        json = JSON.parse(response.body)
        expect(json['data']).to include('total_amount', 'total_transactions')
        
        puts "Aggregation query time: #{query_time.round(3)}s"
      end
    end

    context "concurrent database access" do
      it "maintains performance under concurrent read load" do
        start_time = Time.current
        threads = []
        query_times = []
        
        # Simulate 25 concurrent database reads
        25.times do
          threads << Thread.new do
            request_start = Time.current
            
            # Mix of different query types
            case rand(3)
            when 0
              get "/api/v1/festivals/#{@test_festival.id}", headers: headers
            when 1
              get "/api/v1/festivals/#{@test_festival.id}/payments", 
                  params: { page: rand(5) + 1 }, headers: headers
            when 2
              get "/api/v1/festivals/#{@test_festival.id}/analytics", headers: headers
            end
            
            request_time = Time.current - request_start
            query_times << request_time
            
            expect(response).to have_http_status(:ok)
          end
        end
        
        threads.each(&:join)
        total_time = Time.current - start_time
        
        expect(total_time).to be < 15.seconds
        expect(query_times.max).to be < 3.seconds
        
        puts "Concurrent database reads:"
        puts "  Total time: #{total_time.round(2)}s"
        puts "  Average query time: #{(query_times.sum / query_times.length).round(3)}s"
        puts "  Max query time: #{query_times.max.round(3)}s"
      end
    end
  end

  describe "Memory Usage Tests" do
    it "maintains reasonable memory usage during high load" do
      initial_memory = get_memory_usage
      
      # Perform memory-intensive operations
      50.times do |i|
        get "/api/v1/festivals/#{@test_festival.id}/analytics", headers: headers
        expect(response).to have_http_status(:ok)
        
        # Check memory every 10 requests
        if (i + 1) % 10 == 0
          current_memory = get_memory_usage
          memory_increase = current_memory - initial_memory
          
          # Alert if memory increases too much (more than 50MB)
          if memory_increase > 50
            puts "Warning: Memory usage increased by #{memory_increase}MB"
          end
          
          expect(memory_increase).to be < 100 # Fail if memory increases by more than 100MB
        end
      end
      
      final_memory = get_memory_usage
      memory_change = final_memory - initial_memory
      
      puts "Memory usage change: #{memory_change}MB"
      expect(memory_change).to be < 75 # Allow reasonable memory increase
    end
  end

  describe "Cache Performance Tests" do
    context "when cache is warm" do
      before do
        # Warm up the cache
        get "/api/v1/festivals/#{@test_festival.id}/analytics", headers: headers
      end

      it "serves cached responses quickly" do
        start_time = Time.current
        
        # Make same request that should be cached
        get "/api/v1/festivals/#{@test_festival.id}/analytics", headers: headers
        
        response_time = Time.current - start_time
        
        expect(response).to have_http_status(:ok)
        expect(response_time).to be < 0.5.seconds # Cached responses should be very fast
        
        puts "Cached response time: #{response_time.round(3)}s"
      end
    end

    context "cache invalidation performance" do
      it "handles cache invalidation efficiently" do
        # Warm up cache
        get "/api/v1/festivals/#{@test_festival.id}/analytics", headers: headers
        
        start_time = Time.current
        
        # Create new payment which should invalidate relevant caches
        payment_data = {
          payment: {
            amount: 5000,
            payment_method: 'stripe',
            description: "Cache invalidation test",
            customer_email: user.email,
            customer_name: user.full_name
          }
        }
        
        allow(PaymentService).to receive(:process_payment).and_return({
          success: true,
          transaction_id: 'test_cache_invalidation'
        })
        
        post "/api/v1/festivals/#{festival.id}/payments", 
             params: payment_data.to_json, 
             headers: headers
        
        invalidation_time = Time.current - start_time
        
        expect(response).to have_http_status(:created)
        expect(invalidation_time).to be < 2.seconds
        
        puts "Cache invalidation time: #{invalidation_time.round(3)}s"
      end
    end
  end

  describe "Rate Limiting Performance" do
    it "handles rate limiting efficiently without blocking legitimate requests" do
      start_time = Time.current
      success_count = 0
      rate_limited_count = 0
      
      # Make requests up to and slightly beyond rate limit
      110.times do |i|
        get "/api/v1/festivals", headers: headers
        
        case response.status
        when 200
          success_count += 1
        when 429
          rate_limited_count += 1
        end
      end
      
      total_time = Time.current - start_time
      
      expect(success_count).to be >= 95 # Most requests should succeed
      expect(rate_limited_count).to be > 0 # Some should be rate limited
      expect(total_time).to be < 30.seconds
      
      puts "Rate limiting test:"
      puts "  Successful requests: #{success_count}"
      puts "  Rate limited requests: #{rate_limited_count}"
      puts "  Total time: #{total_time.round(2)}s"
    end
  end

  private

  def get_memory_usage
    # Simple memory usage check (returns MB)
    # In a real implementation, you might use more sophisticated memory monitoring
    output = `ps -o rss -p #{Process.pid}`.lines.last.strip.to_i / 1024
    output
  rescue
    0 # Return 0 if unable to get memory usage
  end
end