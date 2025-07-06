require 'rails_helper'

RSpec.describe Forum, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(Forum).to be_a(Class)
    end
  end
end
