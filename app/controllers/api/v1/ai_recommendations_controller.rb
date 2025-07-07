# frozen_string_literal: true

module Api
  module V1
    # API controller for AI-powered recommendations and analytics
    class AiRecommendationsController < BaseController
      before_action :authenticate_user!
      before_action :set_festival, only: [:attendance_prediction, :layout_optimization, :budget_allocation, :risk_assessment]
      before_action :check_organizer_or_admin_access, only: [:layout_optimization, :budget_allocation, :risk_assessment]

      # POST /api/v1/festivals/:festival_id/ai_recommendations/attendance_prediction
      # Predicts festival attendance using AI algorithms
      def attendance_prediction
        weather_data = attendance_prediction_params[:weather_data] || {}
        historical_data = parse_historical_data(attendance_prediction_params[:historical_data])

        ai_service = AiRecommendationService.new
        result = ai_service.predict_attendance(
          @festival,
          weather_data: weather_data,
          historical_data: historical_data
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Attendance prediction generated successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Attendance prediction error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to generate attendance prediction'
        }, status: :internal_server_error
      end

      # POST /api/v1/festivals/:festival_id/ai_recommendations/layout_optimization
      # Optimizes vendor layout using AI algorithms
      def layout_optimization
        vendors = @festival.vendor_applications.approved.includes(:user)
        constraints = layout_optimization_params[:constraints] || {}

        ai_service = AiRecommendationService.new
        result = ai_service.optimize_vendor_layout(
          @festival.venue,
          vendors,
          constraints: constraints
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Vendor layout optimization completed successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Layout optimization error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to optimize vendor layout'
        }, status: :internal_server_error
      end

      # POST /api/v1/festivals/:festival_id/ai_recommendations/budget_allocation
      # Recommends optimal budget allocation using AI
      def budget_allocation
        total_budget = budget_allocation_params[:total_budget]&.to_f
        historical_performance = parse_historical_performance(budget_allocation_params[:historical_performance])

        return render_validation_error('Total budget is required and must be positive') unless total_budget&.positive?

        ai_service = AiRecommendationService.new
        result = ai_service.recommend_budget_allocation(
          @festival,
          total_budget,
          historical_performance: historical_performance
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Budget allocation recommendations generated successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Budget allocation error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to generate budget allocation recommendations'
        }, status: :internal_server_error
      end

      # POST /api/v1/festivals/:festival_id/ai_recommendations/risk_assessment
      # Performs comprehensive risk assessment using AI
      def risk_assessment
        risk_categories = risk_assessment_params[:risk_categories] || %w[weather safety security financial operational]

        ai_service = AiRecommendationService.new
        result = ai_service.assess_festival_risks(
          @festival,
          risk_categories: risk_categories
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Risk assessment completed successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Risk assessment error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to perform risk assessment'
        }, status: :internal_server_error
      end

      # GET /api/v1/festivals/:festival_id/ai_recommendations/predictive_dashboard
      # Generates comprehensive predictive analytics dashboard
      def predictive_dashboard
        analysis_period = parse_analysis_period(params[:analysis_period])

        analytics_service = AdvancedAnalyticsService.new
        result = analytics_service.generate_predictive_dashboard(
          @festival,
          analysis_period: analysis_period
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Predictive dashboard generated successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Predictive dashboard error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to generate predictive dashboard'
        }, status: :internal_server_error
      end

      # POST /api/v1/festivals/:festival_id/ai_recommendations/roi_optimization
      # Provides ROI optimization recommendations
      def roi_optimization
        investment_scenarios = parse_investment_scenarios(roi_optimization_params[:investment_scenarios])

        analytics_service = AdvancedAnalyticsService.new
        result = analytics_service.optimize_roi(
          @festival,
          investment_scenarios: investment_scenarios
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'ROI optimization analysis completed successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "ROI optimization error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to perform ROI optimization analysis'
        }, status: :internal_server_error
      end

      # GET /api/v1/festivals/:festival_id/ai_recommendations/market_trends
      # Analyzes market trends and provides strategic insights
      def market_trends
        market_scope = params[:market_scope] || 'regional'

        analytics_service = AdvancedAnalyticsService.new
        result = analytics_service.analyze_market_trends(
          @festival,
          market_scope: market_scope
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Market trend analysis completed successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Market trend analysis error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to analyze market trends'
        }, status: :internal_server_error
      end

      # GET /api/v1/festivals/:festival_id/ai_recommendations/performance_benchmark
      # Provides comprehensive benchmarking against similar events
      def performance_benchmark
        benchmark_criteria = params[:benchmark_criteria] || %w[similar_size_events same_category_events regional_events seasonal_events]

        analytics_service = AdvancedAnalyticsService.new
        result = analytics_service.benchmark_performance(
          @festival,
          benchmark_criteria: benchmark_criteria
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Performance benchmarking completed successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Performance benchmarking error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to perform performance benchmarking'
        }, status: :internal_server_error
      end

      # GET /api/v1/festivals/:festival_id/ai_recommendations/realtime_monitoring
      # Generates real-time performance monitoring dashboard
      def realtime_monitoring
        monitoring_metrics = params[:monitoring_metrics] || %w[attendance_rate revenue_per_attendee vendor_satisfaction budget_efficiency safety_incidents customer_satisfaction]

        analytics_service = AdvancedAnalyticsService.new
        result = analytics_service.generate_realtime_monitoring(
          @festival,
          monitoring_metrics: monitoring_metrics
        )

        if result[:success]
          render json: {
            success: true,
            data: result,
            message: 'Real-time monitoring data generated successfully'
          }, status: :ok
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Real-time monitoring error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to generate real-time monitoring data'
        }, status: :internal_server_error
      end

      # GET /api/v1/ai_recommendations/batch_analysis
      # Performs batch analysis across multiple festivals for cross-insights
      def batch_analysis
        festival_ids = params[:festival_ids]&.split(',')&.map(&:to_i)
        analysis_type = params[:analysis_type] || 'performance_trends'

        return render_validation_error('Festival IDs are required') if festival_ids.blank?

        festivals = current_user.accessible_festivals.where(id: festival_ids)
        
        return render_validation_error('No accessible festivals found') if festivals.empty?

        result = perform_batch_analysis(festivals, analysis_type)

        render json: {
          success: true,
          data: result,
          message: 'Batch analysis completed successfully'
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Batch analysis error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to perform batch analysis'
        }, status: :internal_server_error
      end

      # GET /api/v1/ai_recommendations/industry_insights
      # Provides industry-wide insights and trends
      def industry_insights
        industry_scope = params[:industry_scope] || 'national'
        time_period = params[:time_period] || '12_months'

        result = generate_industry_insights(industry_scope, time_period)

        render json: {
          success: true,
          data: result,
          message: 'Industry insights generated successfully'
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Industry insights error: #{e.message}"
        render json: {
          success: false,
          error: 'Failed to generate industry insights'
        }, status: :internal_server_error
      end

      private

      def set_festival
        @festival = current_user.accessible_festivals.find(params[:festival_id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: 'Festival not found or access denied'
        }, status: :not_found
      end

      def check_organizer_or_admin_access
        unless current_user.admin? || @festival.user == current_user
          render json: {
            success: false,
            error: 'Insufficient permissions for this operation'
          }, status: :forbidden
        end
      end

      def attendance_prediction_params
        params.require(:attendance_prediction).permit(
          :historical_data,
          weather_data: [:temperature, :precipitation_probability, :wind_speed, :humidity, :forecast_date]
        )
      end

      def layout_optimization_params
        params.require(:layout_optimization).permit(
          constraints: [:min_distance_between_vendors, :max_walking_distance_to_facilities, :crowd_flow_efficiency, :emergency_access_width]
        )
      end

      def budget_allocation_params
        params.require(:budget_allocation).permit(
          :total_budget,
          :historical_performance
        )
      end

      def risk_assessment_params
        params.require(:risk_assessment).permit(
          risk_categories: []
        )
      end

      def roi_optimization_params
        params.require(:roi_optimization).permit(
          :investment_scenarios
        )
      end

      def parse_historical_data(historical_data_param)
        return [] unless historical_data_param

        JSON.parse(historical_data_param).map(&:with_indifferent_access)
      rescue JSON::ParserError
        []
      end

      def parse_historical_performance(historical_performance_param)
        return [] unless historical_performance_param

        JSON.parse(historical_performance_param).map(&:with_indifferent_access)
      rescue JSON::ParserError
        []
      end

      def parse_analysis_period(analysis_period_param)
        return { start_date: 1.year.ago, end_date: Date.current } unless analysis_period_param

        period_data = JSON.parse(analysis_period_param)
        {
          start_date: Date.parse(period_data['start_date']),
          end_date: Date.parse(period_data['end_date'])
        }
      rescue JSON::ParserError, Date::Error
        { start_date: 1.year.ago, end_date: Date.current }
      end

      def parse_investment_scenarios(scenarios_param)
        return [] unless scenarios_param

        JSON.parse(scenarios_param).map(&:with_indifferent_access)
      rescue JSON::ParserError
        []
      end

      def perform_batch_analysis(festivals, analysis_type)
        case analysis_type
        when 'performance_trends'
          analyze_festival_performance_trends(festivals)
        when 'cost_comparison'
          analyze_festival_cost_comparison(festivals)
        when 'roi_comparison'
          analyze_festival_roi_comparison(festivals)
        when 'risk_aggregation'
          analyze_festival_risk_aggregation(festivals)
        else
          { error: 'Unknown analysis type' }
        end
      end

      def analyze_festival_performance_trends(festivals)
        analytics_service = AdvancedAnalyticsService.new
        
        trends_data = festivals.map do |festival|
          result = analytics_service.analyze_performance_trends(
            festival,
            { start_date: 1.year.ago, end_date: Date.current }
          )
          
          {
            festival_id: festival.id,
            festival_name: festival.name,
            trends: result[:metric_trends] if result[:success]
          }
        end

        {
          analysis_type: 'performance_trends',
          festivals_analyzed: festivals.count,
          trends_data: trends_data,
          cross_festival_insights: generate_cross_festival_insights(trends_data),
          recommendations: generate_batch_recommendations(trends_data)
        }
      end

      def analyze_festival_cost_comparison(festivals)
        cost_data = festivals.map do |festival|
          analytics_service = AdvancedAnalyticsService.new
          result = analytics_service.calculate_current_roi(festival)
          
          {
            festival_id: festival.id,
            festival_name: festival.name,
            venue_capacity: festival.venue&.capacity,
            total_investment: result[:total_investment] if result[:success],
            cost_per_attendee: result[:total_investment] / (festival.venue&.capacity || 1) if result[:success]
          }
        end

        {
          analysis_type: 'cost_comparison',
          festivals_analyzed: festivals.count,
          cost_data: cost_data,
          cost_benchmarks: calculate_cost_benchmarks(cost_data),
          optimization_opportunities: identify_cost_optimization_across_festivals(cost_data)
        }
      end

      def analyze_festival_roi_comparison(festivals)
        roi_data = festivals.map do |festival|
          analytics_service = AdvancedAnalyticsService.new
          result = analytics_service.calculate_current_roi(festival)
          
          {
            festival_id: festival.id,
            festival_name: festival.name,
            roi_percentage: result[:roi_percentage] if result[:success],
            profit_margin: result[:profitability_metrics][:profit_margin] if result[:success] && result[:profitability_metrics]
          }
        end

        {
          analysis_type: 'roi_comparison',
          festivals_analyzed: festivals.count,
          roi_data: roi_data,
          roi_benchmarks: calculate_roi_benchmarks(roi_data),
          performance_ranking: rank_festivals_by_roi(roi_data)
        }
      end

      def analyze_festival_risk_aggregation(festivals)
        risk_data = festivals.map do |festival|
          ai_service = AiRecommendationService.new
          result = ai_service.assess_festival_risks(festival)
          
          {
            festival_id: festival.id,
            festival_name: festival.name,
            overall_risk_score: result[:overall_risk_score] if result[:success],
            critical_risks: result[:critical_risks] if result[:success]
          }
        end

        {
          analysis_type: 'risk_aggregation',
          festivals_analyzed: festivals.count,
          risk_data: risk_data,
          portfolio_risk: calculate_portfolio_risk(risk_data),
          risk_mitigation_priorities: identify_portfolio_risk_priorities(risk_data)
        }
      end

      def generate_cross_festival_insights(trends_data)
        insights = []
        
        # Analyze common trends
        if trends_data.any? { |data| data[:trends] }
          insights << {
            type: 'common_trends',
            message: 'Analyzing common performance patterns across festivals'
          }
        end

        # Performance correlation analysis
        insights << {
          type: 'performance_correlation',
          message: 'Identifying correlations between festival characteristics and performance'
        }

        insights
      end

      def generate_batch_recommendations(trends_data)
        recommendations = []
        
        recommendations << {
          priority: 'high',
          category: 'optimization',
          message: 'Consider standardizing successful practices across all festivals'
        }

        recommendations << {
          priority: 'medium',
          category: 'monitoring',
          message: 'Implement consistent performance monitoring across festival portfolio'
        }

        recommendations
      end

      def calculate_cost_benchmarks(cost_data)
        valid_costs = cost_data.compact.select { |d| d[:cost_per_attendee] }
        return {} if valid_costs.empty?

        cost_per_attendee_values = valid_costs.map { |d| d[:cost_per_attendee] }
        
        {
          average_cost_per_attendee: (cost_per_attendee_values.sum / cost_per_attendee_values.count).round(2),
          median_cost_per_attendee: cost_per_attendee_values.sort[cost_per_attendee_values.count / 2].round(2),
          cost_range: {
            min: cost_per_attendee_values.min.round(2),
            max: cost_per_attendee_values.max.round(2)
          }
        }
      end

      def identify_cost_optimization_across_festivals(cost_data)
        opportunities = []
        
        # Identify high-cost festivals
        avg_cost = cost_data.map { |d| d[:cost_per_attendee] }.compact.sum / cost_data.count
        high_cost_festivals = cost_data.select { |d| d[:cost_per_attendee] && d[:cost_per_attendee] > avg_cost * 1.2 }
        
        if high_cost_festivals.any?
          opportunities << {
            type: 'cost_reduction',
            festivals: high_cost_festivals.map { |f| f[:festival_name] },
            potential_savings: 'Review cost structure for efficiency improvements'
          }
        end

        opportunities
      end

      def calculate_roi_benchmarks(roi_data)
        valid_roi = roi_data.compact.select { |d| d[:roi_percentage] }
        return {} if valid_roi.empty?

        roi_values = valid_roi.map { |d| d[:roi_percentage] }
        
        {
          average_roi: (roi_values.sum / roi_values.count).round(2),
          median_roi: roi_values.sort[roi_values.count / 2].round(2),
          roi_range: {
            min: roi_values.min.round(2),
            max: roi_values.max.round(2)
          }
        }
      end

      def rank_festivals_by_roi(roi_data)
        valid_roi = roi_data.compact.select { |d| d[:roi_percentage] }
        
        valid_roi.sort_by { |d| -d[:roi_percentage] }.each_with_index.map do |festival, index|
          {
            rank: index + 1,
            festival_name: festival[:festival_name],
            roi_percentage: festival[:roi_percentage]
          }
        end
      end

      def calculate_portfolio_risk(risk_data)
        valid_risks = risk_data.compact.select { |d| d[:overall_risk_score] }
        return {} if valid_risks.empty?

        risk_scores = valid_risks.map { |d| d[:overall_risk_score] }
        
        {
          portfolio_average_risk: (risk_scores.sum / risk_scores.count).round(3),
          risk_distribution: {
            low_risk: risk_scores.count { |score| score < 0.4 },
            medium_risk: risk_scores.count { |score| score.between?(0.4, 0.7) },
            high_risk: risk_scores.count { |score| score > 0.7 }
          },
          highest_risk_festival: valid_risks.max_by { |d| d[:overall_risk_score] }[:festival_name]
        }
      end

      def identify_portfolio_risk_priorities(risk_data)
        priorities = []
        
        high_risk_festivals = risk_data.select { |d| d[:overall_risk_score] && d[:overall_risk_score] > 0.7 }
        
        if high_risk_festivals.any?
          priorities << {
            priority: 'immediate',
            action: 'Risk mitigation for high-risk festivals',
            festivals: high_risk_festivals.map { |f| f[:festival_name] }
          }
        end

        priorities
      end

      def generate_industry_insights(industry_scope, time_period)
        # This would analyze industry-wide data
        # For now, return simulated insights
        {
          industry_scope: industry_scope,
          time_period: time_period,
          insights: {
            market_growth: {
              rate: '8.5%',
              trend: 'increasing',
              driver: 'Post-pandemic recovery and increased outdoor activities'
            },
            popular_categories: [
              { category: 'music_festivals', growth: '12%' },
              { category: 'food_festivals', growth: '10%' },
              { category: 'cultural_festivals', growth: '6%' }
            ],
            seasonal_trends: {
              spring: 'High growth in outdoor events',
              summer: 'Peak season with 40% of annual events',
              fall: 'Strong performance in cultural events',
              winter: 'Indoor events and holiday celebrations'
            },
            emerging_trends: [
              'Sustainability focus increasing',
              'Technology integration growing',
              'Hybrid online-offline events emerging',
              'Local community engagement prioritized'
            ]
          },
          recommendations: [
            'Focus on sustainable practices to meet growing demand',
            'Integrate technology for enhanced attendee experience',
            'Consider hybrid event models for broader reach',
            'Emphasize local community partnerships'
          ]
        }
      end

      def render_validation_error(message)
        render json: {
          success: false,
          error: message
        }, status: :unprocessable_entity
      end
    end
  end
end