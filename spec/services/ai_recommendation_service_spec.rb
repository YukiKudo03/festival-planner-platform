# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiRecommendationService, type: :service do
  let(:service) { described_class.new }
  let(:festival) { create(:festival) }
  let(:venue) { create(:venue, capacity: 2000) }
  let(:vendors) { create_list(:vendor_application, 5, festival: festival, status: 'approved') }

  describe '#predict_attendance' do
    context 'with valid festival' do
      it 'returns successful prediction with attendance forecast' do
        result = service.predict_attendance(festival)

        expect(result[:success]).to be true
        expect(result[:predicted_attendance]).to be_a(Integer)
        expect(result[:confidence_score]).to be_between(0, 1)
        expect(result[:factors]).to be_a(Hash)
        expect(result[:recommendations]).to be_an(Array)
      end

      it 'includes weather impact when weather data provided' do
        weather_data = {
          temperature: 25,
          precipitation_probability: 20,
          wind_speed: 10
        }

        result = service.predict_attendance(festival, weather_data: weather_data)

        expect(result[:success]).to be true
        expect(result[:factors][:weather_impact]).to be_present
      end

      it 'uses historical data when provided' do
        historical_data = [
          { attendance: 1500, date: 1.year.ago, weather: 'sunny' },
          { attendance: 1200, date: 6.months.ago, weather: 'rainy' }
        ]

        result = service.predict_attendance(festival, historical_data: historical_data)

        expect(result[:success]).to be true
        expect(result[:factors][:base_prediction]).to be > 0
      end

      it 'generates appropriate recommendations based on capacity' do
        high_capacity_festival = create(:festival, venue: create(:venue, capacity: 10000))
        
        result = service.predict_attendance(high_capacity_festival)

        expect(result[:success]).to be true
        expect(result[:recommendations]).to be_an(Array)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.predict_attendance(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#optimize_vendor_layout' do
    context 'with valid venue and vendors' do
      before do
        festival.update(venue: venue)
      end

      it 'returns successful layout optimization' do
        result = service.optimize_vendor_layout(venue, vendors)

        expect(result[:success]).to be true
        expect(result[:layout]).to be_a(Hash)
        expect(result[:efficiency_score]).to be_between(0, 1)
        expect(result[:crowd_flow_score]).to be_between(0, 1)
        expect(result[:accessibility_score]).to be_between(0, 1)
      end

      it 'includes vendor positions for all vendors' do
        result = service.optimize_vendor_layout(venue, vendors)

        expect(result[:success]).to be true
        expect(result[:layout][:vendor_positions]).to be_a(Hash)
        expect(result[:layout][:vendor_positions].keys.count).to eq(vendors.count)
      end

      it 'includes pathways and emergency exits' do
        result = service.optimize_vendor_layout(venue, vendors)

        expect(result[:success]).to be true
        expect(result[:layout][:pathways]).to be_an(Array)
        expect(result[:layout][:emergency_exits]).to be_an(Array)
        expect(result[:layout][:facility_locations]).to be_a(Hash)
      end

      it 'respects custom constraints' do
        custom_constraints = {
          min_distance_between_vendors: 5.0,
          emergency_access_width: 6.0
        }

        result = service.optimize_vendor_layout(venue, vendors, constraints: custom_constraints)

        expect(result[:success]).to be true
        expect(result[:layout]).to be_a(Hash)
      end

      it 'provides alternative layouts' do
        result = service.optimize_vendor_layout(venue, vendors)

        expect(result[:success]).to be true
        expect(result[:alternative_layouts]).to be_an(Array)
        expect(result[:alternative_layouts].count).to eq(2)
      end

      it 'generates layout recommendations' do
        result = service.optimize_vendor_layout(venue, vendors)

        expect(result[:success]).to be true
        expect(result[:recommendations]).to be_an(Array)
      end
    end

    context 'with invalid input' do
      it 'returns error when venue is nil' do
        result = service.optimize_vendor_layout(nil, vendors)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'returns error when vendors array is empty' do
        result = service.optimize_vendor_layout(venue, [])

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#recommend_budget_allocation' do
    let(:total_budget) { 1000000 }

    context 'with valid festival and budget' do
      it 'returns successful budget allocation recommendation' do
        result = service.recommend_budget_allocation(festival, total_budget)

        expect(result[:success]).to be true
        expect(result[:total_budget]).to eq(total_budget)
        expect(result[:recommended_allocation]).to be_a(Hash)
        expect(result[:allocation_rationale]).to be_a(Hash)
      end

      it 'allocates budget across all required categories' do
        result = service.recommend_budget_allocation(festival, total_budget)

        allocation = result[:recommended_allocation]
        expected_categories = %w[venue_costs marketing_promotion security_safety infrastructure entertainment food_beverage logistics contingency]
        
        expect(allocation.keys.map(&:to_s)).to include(*expected_categories)
        expect(allocation.values.sum).to be_within(1).of(total_budget)
      end

      it 'includes risk assessment in recommendations' do
        result = service.recommend_budget_allocation(festival, total_budget)

        expect(result[:success]).to be true
        expect(result[:risk_assessment]).to be_a(Hash)
        expect(result[:optimization_opportunities]).to be_an(Array)
      end

      it 'provides contingency plan' do
        result = service.recommend_budget_allocation(festival, total_budget)

        expect(result[:success]).to be true
        expect(result[:contingency_plan]).to be_a(Hash)
        expect(result[:contingency_plan][:total_contingency]).to be > 0
      end

      it 'uses historical performance when provided' do
        historical_performance = [
          { category: 'marketing_promotion', efficiency_score: 0.9 },
          { category: 'security_safety', efficiency_score: 0.6 }
        ]

        result = service.recommend_budget_allocation(festival, total_budget, historical_performance: historical_performance)

        expect(result[:success]).to be true
        expect(result[:recommended_allocation]).to be_a(Hash)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.recommend_budget_allocation(nil, total_budget)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'returns error when budget is zero or negative' do
        result = service.recommend_budget_allocation(festival, 0)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'returns error when budget is nil' do
        result = service.recommend_budget_allocation(festival, nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '#assess_festival_risks' do
    context 'with valid festival' do
      it 'returns comprehensive risk assessment' do
        result = service.assess_festival_risks(festival)

        expect(result[:success]).to be true
        expect(result[:overall_risk_score]).to be_between(0, 1)
        expect(result[:risk_level]).to be_in(%w[low medium high critical])
        expect(result[:category_assessments]).to be_a(Hash)
      end

      it 'assesses all default risk categories' do
        result = service.assess_festival_risks(festival)

        expected_categories = %w[weather safety security financial operational]
        expect(result[:category_assessments].keys.map(&:to_s)).to include(*expected_categories)
      end

      it 'identifies critical risks when present' do
        result = service.assess_festival_risks(festival)

        expect(result[:success]).to be true
        expect(result[:critical_risks]).to be_an(Array)
      end

      it 'provides mitigation strategies' do
        result = service.assess_festival_risks(festival)

        expect(result[:success]).to be true
        expect(result[:mitigation_strategies]).to be_a(Hash)
        expect(result[:monitoring_recommendations]).to be_an(Array)
      end

      it 'generates contingency plans for critical risks' do
        result = service.assess_festival_risks(festival)

        expect(result[:success]).to be true
        expect(result[:contingency_plans]).to be_a(Hash)
      end

      it 'respects custom risk categories' do
        custom_categories = %w[weather financial]
        result = service.assess_festival_risks(festival, risk_categories: custom_categories)

        expect(result[:success]).to be true
        expect(result[:category_assessments].keys.map(&:to_s)).to eq(custom_categories)
      end
    end

    context 'with invalid input' do
      it 'returns error when festival is nil' do
        result = service.assess_festival_risks(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe 'error handling' do
    it 'handles service errors gracefully' do
      allow(festival).to receive(:venue).and_raise(StandardError.new('Database connection error'))

      result = service.predict_attendance(festival)

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end

    it 'logs errors appropriately' do
      expect(Rails.logger).to receive(:error).with(/Attendance prediction error/)
      
      allow(festival).to receive(:venue).and_raise(StandardError.new('Test error'))
      service.predict_attendance(festival)
    end
  end

  describe 'configuration and constants' do
    it 'has properly defined prediction factors' do
      expect(AiRecommendationService::ATTENDANCE_PREDICTION_FACTORS).to be_a(Hash)
      expect(AiRecommendationService::ATTENDANCE_PREDICTION_FACTORS.values.sum).to eq(1.0)
    end

    it 'has layout optimization constraints' do
      expect(AiRecommendationService::LAYOUT_OPTIMIZATION_CONSTRAINTS).to be_a(Hash)
      expect(AiRecommendationService::LAYOUT_OPTIMIZATION_CONSTRAINTS).to include(:min_distance_between_vendors)
    end

    it 'has budget allocation categories' do
      expect(AiRecommendationService::BUDGET_ALLOCATION_CATEGORIES).to be_an(Array)
      expect(AiRecommendationService::BUDGET_ALLOCATION_CATEGORIES).to include('venue_costs', 'marketing_promotion')
    end
  end
end