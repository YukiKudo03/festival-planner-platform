require 'rails_helper'

RSpec.describe ForumThread, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(ForumThread).to be_a(Class)
    end
  end
end
