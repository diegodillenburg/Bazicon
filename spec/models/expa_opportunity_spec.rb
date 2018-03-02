require 'rails_helper'

RSpec.describe ExpaOpportunity, type: :model do
  subject { FactoryBot.build(:expa_opportunity) }

  it { is_expected.to have_many(:expa_opportunity_managers) }
end
