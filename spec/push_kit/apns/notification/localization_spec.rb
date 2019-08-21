# frozen_string_literal: true

require 'push_kit/apns/notification/localization'

RSpec.describe PushKit::APNS::Notification::Localization, :unit do
  def localization(params = {})
    default_params = {
      key: 'HELLO_WORLD',
      arguments: nil
    }

    described_class.new(**default_params.merge(params))
  end

  subject { localization }

  it { is_expected.to have_accessor(:key) }
  it { is_expected.to have_accessor(:arguments) }

  describe '#initialize' do
    let(:key)       { 'A_KEY' }
    let(:arguments) { ['An Argument'] }

    subject { localization(key: key, arguments: arguments) }

    it 'sets #key' do
      expect(subject.key).to eq(key)
    end

    it 'sets #arguments' do
      expect(subject.arguments).to eq(arguments)
    end
  end

  describe '#payload' do
    context 'when localizing a supported attribute' do
      let(:payload) { subject.payload(:title) }

      it 'includes #key as the prefixed loc-key attribute' do
        subject.key = 'TITLE_KEY'
        expect(payload).to include('title-loc-key' => 'TITLE_KEY')
      end

      it 'includes #arguments as the prefixed loc-args attribute' do
        subject.arguments = ['An Argument']
        expect(payload).to include('title-loc-args' => ['An Argument'])
      end

      context 'without #arguments' do
        before { subject.arguments = nil }

        it 'excludes the prefixed loc-args attribute' do
          expect(payload).not_to have_key('title-loc-args')
        end
      end
    end

    context 'when localizing an unsupported attribute' do
      let(:attribute) { :some_unknown_attribute }
      let(:payload)   { subject.payload(attribute) }

      it 'returns nil' do
        expect(payload).to be_nil
      end
    end
  end

  describe '#prefix' do
    def prefix(*args)
      subject.instance_eval { prefix(*args) }
    end

    it "returns 'title-' for :title" do
      expect(prefix(:title)).to eq('title-')
    end

    it "returns 'subtitle-' for :subtitle" do
      expect(prefix(:subtitle)).to eq('subtitle-')
    end

    it "returns '' for :body" do
      expect(prefix(:body)).to eq('')
    end

    it 'returns nil for an unknown attribute' do
      expect(prefix(:some_unknown_attribute)).to be_nil
    end
  end
end
