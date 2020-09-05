# frozen_string_literal: true

RSpec.describe Cloudenvoy::Publisher do
  let(:publisher_class) { TestPublisher }
  let(:msg_args) { [{ foo: 'bar' }, { bar: 'foo' }] }
  let(:publisher) { publisher_class.new(msg_args: msg_args) }

  describe '.cloudenvoy_options_hash' do
    subject { publisher_class.cloudenvoy_options_hash }

    let(:opts) { { foo: 'bar' } }
    let!(:original_opts) { publisher_class.cloudenvoy_options_hash }

    before { publisher_class.cloudenvoy_options(opts) }
    after { publisher_class.cloudenvoy_options(original_opts) }
    it { is_expected.to eq(Hash[opts.map { |k, v| [k.to_sym, v] }]) }
  end

  describe '.default_topic' do
    subject { publisher_class.default_topic }

    it { is_expected.to eq(publisher_class.cloudenvoy_options_hash.fetch(:topic)) }
  end

  describe '.publish' do
    subject { publisher_class.publish(*msg_args) }

    let(:publisher) { instance_double('TestPublisher') }
    let(:gcp_msg) { instance_double('Google::Cloud::PubSub::Message') }

    before { expect(publisher_class).to receive(:new).with(msg_args: msg_args).and_return(publisher) }
    before { expect(publisher).to receive(:publish).and_return(gcp_msg) }
    it { is_expected.to eq(gcp_msg) }
  end

  describe '.new' do
    subject { publisher }

    it { is_expected.to have_attributes(msg_args: msg_args) }
  end

  describe '#topic' do
    subject { publisher.topic(*msg_args) }

    it { is_expected.to eq(publisher_class.default_topic) }
  end

  describe '#attributes' do
    subject { publisher.attributes(*msg_args) }

    it { is_expected.to eq({}) }
  end

  describe '#publish' do
    subject { publisher.publish }

    let(:topic) { 'foo-topic' }
    let(:payload) { { formatted: 'payload' } }
    let(:attrs) { { some: 'attrs' } }
    let(:gcp_msg) { instance_double('Google::Cloud::PubSub::Message') }

    before do
      expect(publisher).to receive(:topic).with(*msg_args).and_return(topic)
      expect(publisher).to receive(:payload).with(*msg_args).and_return(payload)
      expect(publisher).to receive(:attributes).with(*msg_args).and_return(attrs)
      expect(Cloudenvoy::PubSubClient).to receive(:publish).with(topic, payload, attrs).and_return(gcp_msg)
    end

    it { is_expected.to eq(gcp_msg) }
  end
end
