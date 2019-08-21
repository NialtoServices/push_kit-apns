# frozen_string_literal: true

require 'push_kit/apns/constants'

RSpec.describe PushKit::APNS do
  it 'has a semantic version' do
    expect(described_class::VERSION).to match(/[0-9]+\.[0-9]+\.[0-9]+/)
  end
end
