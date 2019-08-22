# frozen_string_literal: true

require 'push_kit/apns'

RSpec.describe PushKit::APNS do
  subject { described_class }

  describe '.load_key' do
    context 'when the file does not exist' do
      let(:path) { '/path/to/key' }

      before do
        expect(File).to receive(:file?).with(path).and_return(false)
      end

      it 'raises an ArgumentError' do
        expect { subject.load_key(path) }.to raise_exception(ArgumentError)
      end
    end
  end

  describe '.clients' do
    it 'returns a Hash' do
      expect(subject.clients).to be_a(Hash)
    end
  end

  describe '.prepare' do
    it 'stores the client in #clients' do
      expect(subject).to receive(:client).and_return(:a_client_object)
      subject.prepare(:default)
      expect(subject.clients).to include(default: :a_client_object)
    end
  end
end
