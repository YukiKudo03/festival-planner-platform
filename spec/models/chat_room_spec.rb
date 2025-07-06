require 'rails_helper'

RSpec.describe ChatRoom, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(ChatRoom).to be_a(Class)
    end
  end
end
