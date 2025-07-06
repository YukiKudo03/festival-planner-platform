require 'rails_helper'

RSpec.describe ChatMessage, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(ChatMessage).to be_a(Class)
    end
  end
end
