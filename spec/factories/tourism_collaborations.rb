# frozen_string_literal: true

FactoryBot.define do
  factory :tourism_collaboration do
    association :festival
    association :municipal_authority

    collaboration_type { %w[tourism_board government_liaison economic_development marketing_partnership permit_assistance].sample }
    status { 'draft' }

    partnership_details do
      budget_amount = case collaboration_type
      when 'tourism_board'
                        rand(20000..50000)
      when 'marketing_partnership'
                        rand(10000..30000)
      when 'economic_development'
                        rand(30000..75000)
      when 'government_liaison', 'permit_assistance'
                        0
      else
                        rand(5000..25000)
      end

      resource_list = case collaboration_type
      when 'tourism_board'
                        [ 'marketing_channels', 'visitor_data', 'promotional_materials', 'industry_contacts' ]
      when 'marketing_partnership'
                        [ 'advertising_space', 'social_media_promotion', 'press_releases' ]
      when 'government_liaison'
                        [ 'permit_facilitation', 'regulatory_guidance', 'emergency_services' ]
      when 'permit_assistance'
                        [ 'permit_processing', 'regulatory_compliance', 'inspection_coordination' ]
      else
                        [ 'general_support', 'networking_opportunities' ]
      end

      scope_details = case collaboration_type
      when 'tourism_board'
                        'regional_tourism_promotion_and_visitor_attraction'
      when 'marketing_partnership'
                        'joint_marketing_and_cross_promotion_initiatives'
      when 'government_liaison'
                        'regulatory_compliance_and_government_relations'
      when 'economic_development'
                        'economic_impact_maximization_and_business_development'
      when 'permit_assistance'
                        'streamlined_permitting_and_regulatory_support'
      else
                        'general_collaboration_and_mutual_support'
      end

      deliverables_list = case collaboration_type
      when 'tourism_board'
                            [ 'visitor_analytics_report', 'marketing_campaign_execution', 'tourism_impact_assessment' ]
      when 'marketing_partnership'
                            [ 'co_branded_marketing_materials', 'cross_platform_promotion', 'shared_analytics' ]
      when 'government_liaison'
                            [ 'permit_assistance', 'regulatory_compliance_support', 'emergency_planning' ]
      when 'economic_development'
                            [ 'economic_impact_analysis', 'business_networking_events', 'investment_attraction' ]
      else
                            [ 'collaboration_report', 'mutual_promotion', 'resource_sharing' ]
      end

      timeline_data = {
        planning_phase: { start: 3.months.from_now, end: 2.months.from_now },
        execution_phase: { start: 2.months.from_now, end: 1.week.from_now },
        evaluation_phase: { start: 1.week.from_now, end: 2.weeks.from_now }
      }

      contact_persons_data = [
        {
          name: Faker::Name.name,
          role: [ 'Director', 'Manager', 'Coordinator', 'Specialist' ].sample,
          email: Faker::Internet.email,
          phone: Faker::PhoneNumber.phone_number
        }
      ]

      {
        budget_contribution: budget_amount,
        resource_sharing: resource_list,
        collaboration_scope: scope_details,
        deliverables: deliverables_list,
        timeline: timeline_data,
        contact_persons: contact_persons_data
      }.to_json
    end

    marketing_campaigns do
      social_media_data = {
        platforms: [ 'facebook', 'instagram', 'twitter', 'linkedin' ],
        budget: rand(3000..10000),
        reach_target: rand(10000..50000),
        engagement_target: rand(500..2500),
        content_types: [ 'photos', 'videos', 'stories', 'live_streams' ]
      }

      print_media_data = {
        outlets: [ 'local_newspaper', 'tourism_magazine', 'event_guide' ],
        budget: rand(2000..8000),
        circulation_reach: rand(5000..25000),
        ad_types: [ 'full_page', 'half_page', 'insert' ]
      }

      digital_advertising_data = {
        platforms: [ 'google_ads', 'facebook_ads', 'display_network' ],
        budget: rand(5000..15000),
        target_impressions: rand(50000..200000),
        target_clicks: rand(1000..5000),
        targeting_criteria: [ 'demographics', 'interests', 'location', 'behaviors' ]
      }

      events_promotion_data = {
        promotional_events: [ 'launch_event', 'media_preview', 'community_showcase' ],
        budget: rand(3000..12000),
        expected_attendance: rand(200..1000),
        media_coverage: [ 'local_tv', 'radio', 'online_news' ]
      }

      total_budget = social_media_data[:budget] +
                     print_media_data[:budget] +
                     digital_advertising_data[:budget] +
                     events_promotion_data[:budget]

      {
        social_media: social_media_data,
        print_media: print_media_data,
        digital_advertising: digital_advertising_data,
        events_promotion: events_promotion_data,
        total_budget: total_budget
      }.to_json
    end

    visitor_analytics do
      default_demographics_data = {
        age_groups: { '18-25' => 0, '26-35' => 0, '36-45' => 0, '46-55' => 0, '55+' => 0 },
        geographic_origin: { local: 0, regional: 0, national: 0, international: 0 },
        visitor_type: { first_time: 0, returning: 0 },
        group_size: { individual: 0, couple: 0, family: 0, group: 0 }
      }

      default_satisfaction_data = {
        overall_satisfaction: 0,
        value_for_money: 0,
        organization: 0,
        accessibility: 0,
        entertainment: 0,
        food_beverage: 0
      }

      visitor_source_data = {
        marketing_channels: {
          social_media: rand(25..40),
          word_of_mouth: rand(20..35),
          traditional_media: rand(10..20),
          website: rand(15..25),
          partnerships: rand(5..15)
        },
        referral_sources: {
          tourism_board: rand(15..30),
          local_businesses: rand(10..25),
          other_events: rand(5..15),
          online_listings: rand(10..20)
        }
      }

      spending_patterns_data = {
        average_per_visitor: rand(25..75),
        categories: {
          food_beverage: rand(30..50),
          merchandise: rand(15..30),
          activities: rand(20..35),
          parking: rand(5..15),
          other: rand(5..20)
        },
        payment_methods: {
          cash: rand(40..60),
          card: rand(35..55),
          digital: rand(5..15)
        }
      }

      {
        total_visitors: 0,
        demographics: default_demographics_data,
        economic_impact: 0,
        satisfaction_scores: default_satisfaction_data,
        source_analysis: visitor_source_data,
        spending_patterns: spending_patterns_data
      }.to_json
    end

    # Timestamps
    approved_at { nil }
    activated_at { nil }
    completed_at { nil }
    cancelled_at { nil }

    trait :proposed do
      status { 'proposed' }
    end

    trait :approved do
      status { 'approved' }
      approved_at { 1.week.ago }
    end

    trait :active do
      status { 'active' }
      approved_at { 2.weeks.ago }
      activated_at { 1.week.ago }

      visitor_analytics do
        populated_demographics_data = {
          age_groups: { '18-25' => 20, '26-35' => 35, '36-45' => 25, '46-55' => 15, '55+' => 5 },
          geographic_origin: { local: 40, regional: 35, national: 20, international: 5 },
          visitor_type: { first_time: 65, returning: 35 },
          group_size: { individual: 15, couple: 30, family: 40, group: 15 }
        }

        positive_satisfaction_data = {
          overall_satisfaction: rand(7.5..9.0).round(1),
          value_for_money: rand(7.0..8.5).round(1),
          organization: rand(8.0..9.2).round(1),
          accessibility: rand(7.5..8.8).round(1),
          entertainment: rand(7.8..9.1).round(1),
          food_beverage: rand(7.2..8.7).round(1)
        }

        visitor_source_data = {
          marketing_channels: {
            social_media: rand(25..40),
            word_of_mouth: rand(20..35),
            traditional_media: rand(10..20),
            website: rand(15..25),
            partnerships: rand(5..15)
          },
          referral_sources: {
            tourism_board: rand(15..30),
            local_businesses: rand(10..25),
            other_events: rand(5..15),
            online_listings: rand(10..20)
          }
        }

        spending_patterns_data = {
          average_per_visitor: rand(25..75),
          categories: {
            food_beverage: rand(30..50),
            merchandise: rand(15..30),
            activities: rand(20..35),
            parking: rand(5..15),
            other: rand(5..20)
          },
          payment_methods: {
            cash: rand(40..60),
            card: rand(35..55),
            digital: rand(5..15)
          }
        }

        {
          total_visitors: rand(1000..5000),
          demographics: populated_demographics_data,
          economic_impact: rand(50000..200000),
          satisfaction_scores: positive_satisfaction_data,
          source_analysis: visitor_source_data,
          spending_patterns: spending_patterns_data
        }.to_json
      end
    end

    trait :completed do
      status { 'completed' }
      approved_at { 2.months.ago }
      activated_at { 6.weeks.ago }
      completed_at { 1.week.ago }

      visitor_analytics do
        final_demographics_data = {
          age_groups: { '18-25' => 25, '26-35' => 30, '36-45' => 25, '46-55' => 15, '55+' => 5 },
          geographic_origin: { local: 45, regional: 30, national: 20, international: 5 },
          visitor_type: { first_time: 60, returning: 40 },
          group_size: { individual: 20, couple: 35, family: 35, group: 10 }
        }

        final_satisfaction_data = {
          overall_satisfaction: rand(8.0..9.5).round(1),
          value_for_money: rand(7.5..9.0).round(1),
          organization: rand(8.5..9.5).round(1),
          accessibility: rand(8.0..9.2).round(1),
          entertainment: rand(8.2..9.3).round(1),
          food_beverage: rand(7.8..9.0).round(1)
        }

        final_visitor_source_data = {
          marketing_channels: {
            social_media: rand(30..45),
            word_of_mouth: rand(25..40),
            traditional_media: rand(15..25),
            website: rand(20..30),
            partnerships: rand(10..20)
          },
          referral_sources: {
            tourism_board: rand(20..35),
            local_businesses: rand(15..30),
            other_events: rand(10..20),
            online_listings: rand(15..25)
          }
        }

        final_spending_data = {
          average_per_visitor: rand(40..90),
          categories: {
            food_beverage: rand(35..55),
            merchandise: rand(20..35),
            activities: rand(25..40),
            parking: rand(5..15),
            other: rand(10..25)
          },
          payment_methods: {
            cash: rand(35..55),
            card: rand(40..60),
            digital: rand(10..20)
          }
        }

        {
          total_visitors: rand(3000..8000),
          demographics: final_demographics_data,
          economic_impact: rand(100000..500000),
          satisfaction_scores: final_satisfaction_data,
          source_analysis: final_visitor_source_data,
          spending_patterns: final_spending_data
        }.to_json
      end
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { 1.week.ago }
    end

    trait :tourism_board do
      collaboration_type { 'tourism_board' }

      partnership_details do
        {
          budget_contribution: 25000,
          resource_sharing: [ 'marketing_channels', 'visitor_data', 'promotional_materials' ],
          collaboration_scope: 'regional_tourism_promotion',
          deliverables: [ 'visitor_analytics_report', 'marketing_campaign_execution', 'post_event_assessment' ],
          timeline: { start: 3.months.from_now, end: 6.months.from_now },
          contact_persons: [ { name: 'Jane Smith', role: 'Tourism Director', email: 'jane@tourism.gov' } ]
        }.to_json
      end
    end

    trait :marketing_partnership do
      collaboration_type { 'marketing_partnership' }

      partnership_details do
        {
          budget_contribution: 15000,
          resource_sharing: [ 'advertising_space', 'social_media_promotion', 'press_releases' ],
          collaboration_scope: 'joint_marketing_initiatives',
          deliverables: [ 'co_branded_campaigns', 'cross_promotion', 'shared_analytics' ],
          timeline: { start: 2.months.from_now, end: 4.months.from_now },
          contact_persons: [ { name: 'Mike Johnson', role: 'Marketing Manager', email: 'mike@city.gov' } ]
        }.to_json
      end
    end

    trait :government_liaison do
      collaboration_type { 'government_liaison' }

      partnership_details do
        {
          budget_contribution: 0,
          resource_sharing: [ 'permit_facilitation', 'regulatory_guidance', 'emergency_services_coordination' ],
          collaboration_scope: 'regulatory_compliance_and_safety',
          deliverables: [ 'permit_assistance', 'safety_planning', 'emergency_response_coordination' ],
          timeline: { start: 4.months.from_now, end: 7.months.from_now },
          contact_persons: [ { name: 'Sarah Davis', role: 'City Liaison', email: 'sarah@city.gov' } ]
        }.to_json
      end
    end

    trait :high_impact do
      visitor_analytics do
        high_impact_demographics_data = {
          age_groups: { '18-25' => 18, '26-35' => 32, '36-45' => 28, '46-55' => 17, '55+' => 5 },
          geographic_origin: { local: 35, regional: 35, national: 25, international: 5 },
          visitor_type: { first_time: 70, returning: 30 },
          group_size: { individual: 10, couple: 25, family: 45, group: 20 }
        }

        excellent_satisfaction_data = {
          overall_satisfaction: rand(8.5..10.0).round(1),
          value_for_money: rand(8.0..9.5).round(1),
          organization: rand(9.0..10.0).round(1),
          accessibility: rand(8.5..9.5).round(1),
          entertainment: rand(8.8..9.8).round(1),
          food_beverage: rand(8.2..9.5).round(1)
        }

        diverse_visitor_source_data = {
          marketing_channels: {
            social_media: rand(35..50),
            word_of_mouth: rand(30..45),
            traditional_media: rand(20..30),
            website: rand(25..35),
            partnerships: rand(15..25)
          },
          referral_sources: {
            tourism_board: rand(25..40),
            local_businesses: rand(20..35),
            other_events: rand(15..25),
            online_listings: rand(20..30)
          }
        }

        high_spending_data = {
          average_per_visitor: rand(60..120),
          categories: {
            food_beverage: rand(40..60),
            merchandise: rand(25..40),
            activities: rand(30..45),
            parking: rand(8..18),
            other: rand(15..30)
          },
          payment_methods: {
            cash: rand(30..50),
            card: rand(45..65),
            digital: rand(15..25)
          }
        }

        {
          total_visitors: rand(8000..15000),
          demographics: high_impact_demographics_data,
          economic_impact: rand(300000..1000000),
          satisfaction_scores: excellent_satisfaction_data,
          source_analysis: diverse_visitor_source_data,
          spending_patterns: high_spending_data
        }.to_json
      end
    end
  end
end
