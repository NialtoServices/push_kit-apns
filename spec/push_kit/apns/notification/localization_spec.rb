# frozen_string_literal: true

require 'push_kit/apns/notification/localization'

RSpec.describe PushKit::APNS::Notification::Localization, :unit do
  def build(params = {})
    default_params = {
      key: 'HELLO_WORLD',
      arguments: nil
    }

    described_class.new(**default_params.merge(params))
  end

  subject(:localization) { build }

  it { is_expected.to have_accessor(:key) }
  it { is_expected.to have_accessor(:arguments) }

  describe '#initialize' do
    let(:key)       { 'A_KEY' }
    let(:arguments) { ['An argument'] }

    subject { build(key: key, arguments: arguments) }

    it 'sets #key' do
      expect(subject.key).to eq(key)
    end

    it 'sets #arguments' do
      expect(subject.arguments).to eq(arguments)
    end
  end

  describe '#payload' do
    context 'when localizing a supported attribute' do
      subject { localization.payload(:title) }

      context 'when #key is set' do
        before { localization.key = 'TITLE_KEY' }

        it 'includes the correct loc-key attribute and value' do
          expect(subject).to include('title-loc-key' => 'TITLE_KEY')
        end
      end

      context 'when #arguments is set' do
        before { localization.arguments = ['An argument'] }

        it 'includes the correct loc-args attribute and value' do
          expect(subject).to include('title-loc-args' => ['An argument'])
        end
      end

      context 'when #arguments is nil' do
        before { localization.arguments = nil }

        it 'excludes the correct loc-args attribute' do
          expect(subject).not_to have_key('title-loc-args')
        end
      end
    end

    context 'when localizing an unsupported attribute' do
      subject { localization.payload(:some_unknown_attribute) }

      it 'returns nil' do
        expect(subject).to be nil
      end
    end
  end

  describe '#prefix' do
    def self.it_returns(prefix, with: nil)
      context "with :#{with}" do
        subject { prefix(with) }

        it "returns '#{prefix}'" do
          expect(subject).to eq(prefix)
        end
      end
    end

    def prefix(*args)
      localization.instance_eval { prefix(*args) }
    end

    it_returns 'title-',    with: :title
    it_returns 'subtitle-', with: :subtitle
    it_returns '',          with: :body

    context 'with an unknown attribute' do
      subject { prefix(:some_unknown_attribute) }

      it 'returns nil' do
        expect(subject).to be nil
      end
    end
  end
end
