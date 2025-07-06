require 'rails_helper'

RSpec.describe Booth, type: :model do
  describe 'constants' do
    it 'defines booth sizes' do
      expect(Booth::SIZES).to include('small', 'medium', 'large', 'extra_large', 'custom')
    end

    it 'defines booth statuses' do
      expect(Booth::STATUSES).to include('available', 'reserved', 'assigned', 'occupied', 'maintenance', 'unavailable')
    end
  end

  describe 'class methods' do
    describe '.generate_booth_number' do
      it 'generates correct booth number format' do
        number = Booth.generate_booth_number(1, 0, 0)
        expect(number).to eq('01-001')
        
        number = Booth.generate_booth_number(1, 2, 15)
        expect(number).to eq('03-016')
      end
    end
  end

  describe 'instance methods' do
    let(:booth) { Booth.new(size: 'small', width: 4, height: 6, x_position: 10, y_position: 20, status: 'available') }

    describe '#size_text' do
      it 'returns proper Japanese text for sizes' do
        booth.size = 'small'
        expect(booth.size_text).to eq('小 (3m×3m)')
        
        booth.size = 'medium'
        expect(booth.size_text).to eq('中 (4m×4m)')
      end
    end

    describe '#total_area' do
      it 'calculates total area correctly' do
        booth.width = 4
        booth.height = 5
        expect(booth.total_area).to eq(20)
      end
    end

    describe '#is_available?' do
      it 'returns true when status is available' do
        booth.status = 'available'
        expect(booth.is_available?).to be true
      end
      
      it 'returns false when status is not available' do
        booth.status = 'assigned'
        expect(booth.is_available?).to be false
      end
    end

    describe '#status_text' do
      it 'returns proper Japanese text for statuses' do
        booth.status = 'available'
        expect(booth.status_text).to eq('利用可能')
        
        booth.status = 'assigned'
        expect(booth.status_text).to eq('割り当て済み')
      end
    end

    describe '#center_point' do
      it 'calculates center point correctly' do
        center = booth.center_point
        expect(center[:x]).to eq(12)
        expect(center[:y]).to eq(23)
      end
    end
  end
end
