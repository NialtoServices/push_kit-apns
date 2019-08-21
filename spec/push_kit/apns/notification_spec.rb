# frozen_string_literal: true

require 'time'
require 'push_kit/apns/notification'
require 'push_kit/apns/notification/localization'

RSpec.describe PushKit::APNS::Notification, :unit do
  describe '::PRIORITIES' do
    subject { described_class::PRIORITIES }

    it { is_expected.to have_key(:eco) }
    it { is_expected.to have_key(:immediate) }
  end

  it { is_expected.to have_accessor(:title) }
  it { is_expected.to have_accessor(:subtitle) }
  it { is_expected.to have_accessor(:body) }
  it { is_expected.to have_accessor(:badge) }
  it { is_expected.to have_accessor(:sound) }
  it { is_expected.to have_accessor(:action_key) }
  it { is_expected.to have_accessor(:category) }
  it { is_expected.to have_accessor(:launch_image) }
  it { is_expected.to have_accessor(:metadata) }
  it { is_expected.to have_accessor(:content_available) }
  it { is_expected.to have_accessor(:mutable_content) }
  it { is_expected.to have_accessor(:uuid) }
  it { is_expected.to have_accessor(:collapse_uuid) }
  it { is_expected.to have_accessor(:priority) }
  it { is_expected.to have_accessor(:expiration) }
  it { is_expected.to have_accessor(:device_token) }

  describe '#initialize' do
    it 'sets #content_available to false' do
      expect(subject.content_available).to be false
    end

    it 'sets #mutable_content to false' do
      expect(subject.mutable_content).to be false
    end
  end

  describe '#apns_priority' do
    let(:value) { 10 }

    context 'when #priority is a valid Symbol' do
      before { subject.priority = :immediate }

      it 'returns the numerical value' do
        expect(subject.apns_priority).to eq(value)
      end
    end

    context 'when #priority is not a valid Symbol' do
      before { subject.priority = :some_unacceptable_symbol }

      it 'returns nil' do
        expect(subject.apns_priority).to be nil
      end
    end

    context 'when #priority is not a Symbol' do
      before { subject.priority = value }

      it 'returns the exact value of #priority' do
        expect(subject.apns_priority).to eq(value)
      end
    end
  end

  describe '#apns_expiration' do
    let(:value) { 10 }

    context 'when #expiration is a Time' do
      before { subject.expiration = Time.iso8601('1970-01-01T00:00:10Z') }

      it 'returns the Time represented as a UNIX timestamp' do
        expect(subject.apns_expiration).to eq(value)
      end
    end

    context 'when #expiration is not a Time' do
      before { subject.expiration = value }

      it 'returns the exact value of #expiration' do
        expect(subject.apns_expiration).to eq(value)
      end
    end
  end

  describe '#for_tokens' do
    let(:tokens) do
      %w[
        1111111111111111111111111111111111111111111111111111111111111111
        2222222222222222222222222222222222222222222222222222222222222222
        3333333333333333333333333333333333333333333333333333333333333333
      ]
    end

    it 'returns a notification for each of provided device tokens' do
      notifications = subject.for_tokens(*tokens)
      expect(notifications).to all(be_a described_class)
      expect(notifications).to contain_exactly(
        have_attributes(device_token: '1111111111111111111111111111111111111111111111111111111111111111'),
        have_attributes(device_token: '2222222222222222222222222222222222222222222222222222222222222222'),
        have_attributes(device_token: '3333333333333333333333333333333333333333333333333333333333333333')
      )
    end
  end

  describe '#headers' do
    it 'uses #apns_priority' do
      expect(subject).to receive(:apns_priority).at_least(:once)
      subject.headers
    end

    it 'uses #apns_expiration' do
      expect(subject).to receive(:apns_expiration).at_least(:once)
      subject.headers
    end

    it 'includes #uuid' do
      subject.uuid = 'ABCD1234-ABCD-1234-5678-ABCDEF123456'
      expect(subject.headers).to include('apns-id' => 'ABCD1234-ABCD-1234-5678-ABCDEF123456')
    end

    it 'includes #collapse_uuid' do
      subject.collapse_uuid = 'ABCD1234-ABCD-1234-5678-ABCDEF123456'
      expect(subject.headers).to include('apns-collapse-id' => 'ABCD1234-ABCD-1234-5678-ABCDEF123456')
    end

    it 'includes #priority' do
      subject.priority = 10
      expect(subject.headers).to include('apns-priority' => 10)
    end

    it 'includes #expiration' do
      subject.expiration = 10
      expect(subject.headers).to include('apns-expiration' => 10)
    end
  end

  describe '#payload' do
    let(:payload) { subject.payload }

    it 'includes #metadata' do
      subject.metadata = { 'key' => 'value' }
      expect(payload).to include('key' => 'value')
    end

    it 'includes #payload_aps' do
      expect(subject).to receive(:payload_aps).and_return('key' => 'value')
      expect(payload).to include('aps' => { 'key' => 'value' })
    end
  end

  describe '#payload_aps' do
    let(:payload_aps) do
      subject.instance_eval { payload_aps }
    end

    it 'includes #payload_alert' do
      expect(subject).to receive(:payload_alert).and_return('key' => 'value')
      expect(payload_aps).to include('alert' => { 'key' => 'value' })
    end

    it 'includes #badge' do
      subject.badge = 10
      expect(payload_aps).to include('badge' => 10)
    end

    it 'includes #sound' do
      subject.sound = 'default'
      expect(payload_aps).to include('sound' => 'default')
    end

    it 'converts #sound into a String given a Symbol' do
      subject.sound = :default
      expect(payload_aps).to include('sound' => 'default')
    end

    it 'includes #category' do
      subject.category = 'GENERAL'
      expect(payload_aps).to include('category' => 'GENERAL')
    end

    it 'includes #content_available when truthy' do
      subject.content_available = true
      expect(payload_aps).to include('content-available' => '1')
    end

    it 'excludes #content_available when falsey' do
      subject.content_available = false
      expect(payload_aps).not_to have_key('content-available')
    end

    it 'includes #mutable_content when truthy' do
      subject.mutable_content = true
      expect(payload_aps).to include('mutable-content' => '1')
    end

    it 'excludes #mutable_content when falsey' do
      subject.mutable_content = false
      expect(payload_aps).not_to have_key('mutable-content')
    end
  end

  describe '#payload_alert' do
    let(:payload_alert) do
      subject.instance_eval { payload_alert }
    end

    it 'includes #title' do
      subject.title = 'A title'
      expect(payload_alert).to include('title' => 'A title')
    end

    it 'includes #subtitle' do
      subject.subtitle = 'A subtitle'
      expect(payload_alert).to include('subtitle' => 'A subtitle')
    end

    it 'includes #body' do
      subject.body = 'A body'
      expect(payload_alert).to include('body' => 'A body')
    end

    it 'includes #action_key' do
      subject.action_key = 'ACTION_TITLE'
      expect(payload_alert).to include('action-loc-key' => 'ACTION_TITLE')
    end

    it 'includes #launch_image' do
      subject.launch_image = 'launch.png'
      expect(payload_alert).to include('launch-image' => 'launch.png')
    end

    context 'when localizing attributes' do
      let(:localization) { instance_double(PushKit::APNS::Notification::Localization) }

      before do
        allow(localization).to receive(:is_a?).and_return(false)
        allow(localization).to receive(:is_a?).with(PushKit::APNS::Notification::Localization).and_return(true)
      end

      it 'includes the localization payload for #title' do
        subject.title = localization
        expect(localization).to receive(:payload).with(:title).and_return(localization: :some_value)
        expect(payload_alert).to include(localization: :some_value)
      end

      it 'includes the localization payload for #subtitle' do
        subject.subtitle = localization
        expect(localization).to receive(:payload).with(:subtitle).and_return(localization: :some_value)
        expect(payload_alert).to include(localization: :some_value)
      end

      it 'includes the localization payload for #body' do
        subject.body = localization
        expect(localization).to receive(:payload).with(:body).and_return(localization: :some_value)
        expect(payload_alert).to include(localization: :some_value)
      end
    end
  end
end
