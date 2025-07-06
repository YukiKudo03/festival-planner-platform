require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the Admin::VendorApplicationsHelper. For example:
#
# describe Admin::VendorApplicationsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe Admin::VendorApplicationsHelper, type: :helper do
  it "exists as a module" do
    expect(described_class).to be_a(Module)
  end
end
