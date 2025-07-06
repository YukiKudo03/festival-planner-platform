require 'rails_helper'

RSpec.describe ChatRoomMember, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(ChatRoomMember).to be_a(Class)
    end
  end
end
