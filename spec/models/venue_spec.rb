require 'rails_helper'

RSpec.describe Venue, type: :model do
  describe 'constants' do
    it 'defines facility types' do
      expect(Venue::FACILITY_TYPES).to include('indoor', 'outdoor', 'mixed', 'pavilion', 'arena', 'stadium')
    end

    it 'exists as a model' do
      expect(Venue).to be_a(Class)
    end
  end
end
