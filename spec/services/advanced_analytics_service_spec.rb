# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvancedAnalyticsService, type: :service do
  let(:service) { described_class.new }
  let(:festival) { create(:festival) }
  let(:venue) { create(:venue, capacity: 2000) }

  before do
    festival.update(venue: venue)
  end

  describe '#generate_predictive_dashboard' do
    context 'with valid festival' do
      it 'returns comprehensive dashboard data' do
        result = service.generate_predictive_dashboard(festival)

        expect(result[:success]).to be true
        expect(result[:festival_id]).to eq(festival.id)
        expect(result[:dashboard_data]).to be_a(Hash)
        expect(result[:generated_at]).to be_present
      end

      it 'includes all dashboard components' do
        result = service.generate_predictive_dashboard(festival)

        dashboard_data = result[:dashboard_data]
        expected_components = %w[attendance_forecast revenue_projections risk_indicators performance_trends optimization_opportunities competitor_analysis summary_insights]

        expected_components.each do |component|
          expect(dashboard_data).to have_key(component.to_sym)
        end
      end

      it 'includes attendance forecast with confidence intervals' do
        result = service.generate_predictive_dashboard(festival)

        attendance_forecast = result[:dashboard_data][:attendance_forecast]
        expect(attendance_forecast[:total_predicted_attendance]).to be_a(Integer)
        expect(attendance_forecast[:confidence_score]).to be_between(0, 1)
        expect(attendance_forecast[:daily_forecast]).to be_an(Array)
      end

      it 'includes revenue projections with different scenarios' do
        result = service.generate_predictive_dashboard(festival)

        revenue_projections = result[:dashboard_data][:revenue_projections]
        expect(revenue_projections[:revenue_streams]).to be_a(Hash)
        expect(revenue_projections[:total_projected_revenue]).to be_a(Numeric)
        expect(revenue_projections[:scenario_analysis]).to be_a(Hash)
      end

      it 'respects custom analysis period' do
        custom_period = { start_date: 6.months.ago, end_date: Date.current }
        result = service.generate_predictive_dashboard(festival, analysis_period: custom_period)

        expect(result[:success]).to be true
        expect(result[:analysis_period]).to eq(custom_period)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.generate_predictive_dashboard(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#optimize_roi' do
    context 'with valid festival' do
      it 'returns ROI optimization analysis' do
        result = service.optimize_roi(festival)

        expect(result[:success]).to be true
        expect(result[:festival_id]).to eq(festival.id)
        expect(result[:current_roi]).to be_a(Hash)
        expect(result[:historical_analysis]).to be_a(Hash)
      end

      it 'calculates current ROI metrics' do
        result = service.optimize_roi(festival)

        current_roi = result[:current_roi]
        expect(current_roi[:total_revenue]).to be_a(Numeric)
        expect(current_roi[:total_investment]).to be_a(Numeric)
        expect(current_roi[:roi_percentage]).to be_a(Numeric)
        expect(current_roi[:roi_category]).to be_present
      end

      it 'provides optimization recommendations' do
        result = service.optimize_roi(festival)

        expect(result[:optimization_recommendations]).to be_an(Array)
        expect(result[:improvement_projections]).to be_a(Hash)
        expect(result[:implementation_priority]).to be_present
      end

      it 'analyzes investment scenarios when provided' do
        scenarios = [
          { name: 'Marketing Boost', investment: 100000, expected_return: 150000 },
          { name: 'Infrastructure Upgrade', investment: 200000, expected_return: 250000 }
        ]

        result = service.optimize_roi(festival, investment_scenarios: scenarios)

        expect(result[:success]).to be true
        expect(result[:scenario_analysis]).to be_an(Array)
        expect(result[:scenario_analysis].count).to eq(scenarios.count)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.optimize_roi(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#analyze_market_trends' do
    context 'with valid festival' do
      it 'returns comprehensive market analysis' do
        result = service.analyze_market_trends(festival)

        expect(result[:success]).to be true
        expect(result[:festival_id]).to eq(festival.id)
        expect(result[:market_scope]).to eq('regional')
        expect(result[:industry_trends]).to be_a(Hash)
      end

      it 'includes all trend analysis components' do
        result = service.analyze_market_trends(festival)

        expected_components = %w[industry_trends seasonal_patterns consumer_insights competitive_landscape market_predictions strategic_recommendations action_items]

        expected_components.each do |component|
          expect(result).to have_key(component.to_sym)
        end
      end

      it 'respects market scope parameter' do
        result = service.analyze_market_trends(festival, market_scope: 'national')

        expect(result[:success]).to be true
        expect(result[:market_scope]).to eq('national')
      end

      it 'generates actionable recommendations' do
        result = service.analyze_market_trends(festival)

        expect(result[:strategic_recommendations]).to be_an(Array)
        expect(result[:action_items]).to be_an(Array)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.analyze_market_trends(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#benchmark_performance' do
    context 'with valid festival' do
      it 'returns comprehensive benchmarking analysis' do
        result = service.benchmark_performance(festival)

        expect(result[:success]).to be true
        expect(result[:festival_id]).to eq(festival.id)
        expect(result[:benchmarking_results]).to be_a(Hash)
      end

      it 'benchmarks against all default criteria' do
        result = service.benchmark_performance(festival)

        expected_criteria = %w[similar_size_events same_category_events regional_events seasonal_events]
        expect(result[:benchmarking_results].keys.map(&:to_s)).to include(*expected_criteria)
      end

      it 'provides overall ranking and competitive position' do
        result = service.benchmark_performance(festival)

        expect(result[:overall_ranking]).to be_a(Hash)
        expect(result[:competitive_position]).to be_a(Hash)
      end

      it 'identifies best practices and improvement recommendations' do
        result = service.benchmark_performance(festival)

        expect(result[:best_practices]).to be_an(Array)
        expect(result[:improvement_recommendations]).to be_an(Array)
        expect(result[:performance_gaps]).to be_an(Array)
      end

      it 'respects custom benchmark criteria' do
        custom_criteria = %w[similar_size_events regional_events]
        result = service.benchmark_performance(festival, benchmark_criteria: custom_criteria)

        expect(result[:success]).to be true
        expect(result[:benchmarking_results].keys.map(&:to_s)).to eq(custom_criteria)
      end

      it 'generates action plan' do
        result = service.benchmark_performance(festival)

        expect(result[:action_plan]).to be_an(Array)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.benchmark_performance(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#generate_realtime_monitoring' do
    context 'with valid festival' do
      it 'returns real-time monitoring data' do
        result = service.generate_realtime_monitoring(festival)

        expect(result[:success]).to be true
        expect(result[:festival_id]).to eq(festival.id)
        expect(result[:monitoring_timestamp]).to be_present
        expect(result[:monitoring_data]).to be_a(Hash)
      end

      it 'monitors all default metrics' do
        result = service.generate_realtime_monitoring(festival)

        expected_metrics = %w[attendance_rate revenue_per_attendee vendor_satisfaction budget_efficiency safety_incidents customer_satisfaction]
        expect(result[:monitoring_data].keys.map(&:to_s)).to include(*expected_metrics)
      end

      it 'generates performance alerts' do
        result = service.generate_realtime_monitoring(festival)

        expect(result[:performance_alerts]).to be_an(Array)
        expect(result[:immediate_actions]).to be_an(Array)
      end

      it 'includes trend indicators and dashboard widgets' do
        result = service.generate_realtime_monitoring(festival)

        expect(result[:trend_indicators]).to be_a(Hash)
        expect(result[:dashboard_widgets]).to be_a(Hash)
        expect(result[:refresh_interval]).to be_a(Integer)
      end

      it 'respects custom monitoring metrics' do
        custom_metrics = %w[attendance_rate revenue_per_attendee]
        result = service.generate_realtime_monitoring(festival, monitoring_metrics: custom_metrics)

        expect(result[:success]).to be true
        expect(result[:monitoring_data].keys.map(&:to_s)).to eq(custom_metrics)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.generate_realtime_monitoring(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe 'error handling' do
    it 'handles service errors gracefully' do
      allow(festival).to receive(:venue).and_raise(StandardError.new('Database connection error'))

      result = service.generate_predictive_dashboard(festival)

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end

    it 'logs errors appropriately' do
      expect(Rails.logger).to receive(:error).with(/Predictive dashboard generation error/)

      allow(festival).to receive(:venue).and_raise(StandardError.new('Test error'))
      service.generate_predictive_dashboard(festival)
    end
  end

  describe 'configuration and constants' do
    it 'has properly defined trend analysis periods' do
      expect(AdvancedAnalyticsService::TREND_ANALYSIS_PERIODS).to be_a(Hash)
      expect(AdvancedAnalyticsService::TREND_ANALYSIS_PERIODS).to include(:short_term, :medium_term, :long_term)
    end

    it 'has performance metrics defined' do
      expect(AdvancedAnalyticsService::PERFORMANCE_METRICS).to be_an(Array)
      expect(AdvancedAnalyticsService::PERFORMANCE_METRICS).to include('attendance_rate', 'revenue_per_attendee')
    end

    it 'has benchmark categories defined' do
      expect(AdvancedAnalyticsService::BENCHMARK_CATEGORIES).to be_an(Array)
      expect(AdvancedAnalyticsService::BENCHMARK_CATEGORIES).to include('similar_size_events', 'same_category_events')
    end
  end

  describe 'integration with AI recommendation service' do
    it 'integrates with attendance prediction' do
      result = service.generate_predictive_dashboard(festival)

      attendance_forecast = result[:dashboard_data][:attendance_forecast]
      expect(attendance_forecast[:total_predicted_attendance]).to be_present
      expect(attendance_forecast[:confidence_score]).to be_present
    end

    it 'integrates with risk assessment' do
      result = service.generate_predictive_dashboard(festival)

      risk_indicators = result[:dashboard_data][:risk_indicators]
      expect(risk_indicators[:overall_risk_assessment]).to be_present
    end
  end
end
