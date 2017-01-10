require 'rails_helper'
require 'expa_rd_sync/list_open'

RSpec.describe ExpaRdSync::ListOpen do
  let(:job) { ExpaRdSync::ListOpen.new }

  subject { job }

  it { is_expected.to respond_to(:call) }

  it { is_expected.to respond_to(:rd_identifiers) }

  it { is_expected.to respond_to(:rd_tags) }

  it { is_expected.to respond_to(:status) }
end
