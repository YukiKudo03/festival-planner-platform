require 'rails_helper'

RSpec.describe ForumPost, type: :model do
  describe 'constants' do
    it 'exists as a model' do
      expect(ForumPost).to be_a(Class)
    end
  end
end
