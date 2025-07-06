require 'rails_helper'

RSpec.describe Reaction, type: :model do
  describe 'constants' do
    it 'defines reaction types' do
      expect(Reaction::REACTION_TYPES).to include('like', 'love', 'laugh', 'wow', 'sad', 'angry')
    end
  end

  describe 'class methods' do
    describe '.emoji_for' do
      it 'returns correct emoji for reaction types' do
        expect(Reaction.emoji_for('like')).to eq('👍')
        expect(Reaction.emoji_for('love')).to eq('❤️')
        expect(Reaction.emoji_for('laugh')).to eq('😂')
        expect(Reaction.emoji_for('wow')).to eq('😮')
        expect(Reaction.emoji_for('sad')).to eq('😢')
        expect(Reaction.emoji_for('angry')).to eq('😡')
      end
      
      it 'returns default emoji for unknown types' do
        expect(Reaction.emoji_for('unknown')).to eq('👍')
      end
    end
  end

  describe 'instance methods' do
    let(:reaction) { Reaction.new(reaction_type: 'love') }

    describe '#emoji' do
      it 'returns emoji for the reaction type' do
        expect(reaction.emoji).to eq('❤️')
      end
    end
  end
end
