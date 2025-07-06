require 'rails_helper'

RSpec.describe VenueArea, type: :model do
  describe 'constants' do
    it 'defines area types' do
      expect(VenueArea::AREA_TYPES).to include('vendor_area', 'food_court', 'stage', 'seating', 'performance_area')
    end
    
    it 'exists as a model' do
      expect(VenueArea).to be_a(Class)
    end
  end
end
