require 'rails_helper'

RSpec.describe LayoutElement, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(LayoutElement).to be_a(Class)
    end
  end
end
