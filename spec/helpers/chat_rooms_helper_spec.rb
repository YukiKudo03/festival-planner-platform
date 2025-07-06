require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the ChatRoomsHelper. For example:
#
# describe ChatRoomsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe ChatRoomsHelper, type: :helper do
  describe "helper methods" do
    it "provides basic functionality" do
      # Since this helper has no methods currently, just test it exists
      expect(ChatRoomsHelper).to be_a(Module)
    end
  end
end
