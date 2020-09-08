# frozen_string_literal: true

RSpec.describe Cloudenvoy::Subscriber do
  let(:subscriber_class) { TestSubscriber }
  let(:msg_id) { '1234' }
  let(:payload) { { 'username' => 'john' } }
  let(:metadata) { { 'some' => 'attrs' } }
  let(:topic) { 'foo-topic' }
  let(:sub_uri) { "projects/some-proj/subscriptions/some-app.#{subscriber_class.to_s.underscore}.#{topic}" }
  let(:message) { Cloudenvoy::Message.new(id: msg_id, payload: payload, metadata: metadata, sub_uri: sub_uri) }
  let(:subscriber) { subscriber_class.new(message: message) }

  let(:descriptor_sub) { sub_uri }
  let(:descriptor) do
    {
      'message' => {
        'attributes' => metadata,
        'data' => Base64.strict_encode64(payload.to_json),
        'message_id' => msg_id
      },
      'subscription' => descriptor_sub
    }
  end

  describe '.from_sub_uri' do
    subject { described_class.from_sub_uri(sub_uri) }

    context 'with valid subscriber' do
      it { is_expected.to eq(TestSubscriber) }
    end

    context 'with invalid subscriber' do
      let(:subscriber_class) { String }

      it { is_expected.to be_nil }
    end
  end

  describe '.parse_sub_uri' do
    subject { described_class.parse_sub_uri(sub_uri) }

    it { is_expected.to eq([subscriber_class.to_s.underscore, topic]) }
  end

  describe '.execute_from_descriptor' do
    subject(:execute) { described_class.execute_from_descriptor(descriptor) }

    let(:ret_msg) { instance_double('Cloudenvoy::Message', subscriber: ret_sub) }
    let(:ret_sub) { subscriber }

    before { expect(Cloudenvoy::Message).to receive(:from_descriptor).with(descriptor).and_return(ret_msg) }

    context 'with valid subscriber' do
      let(:resp) { 'some-response' }

      before { expect(ret_sub).to receive(:execute).and_return(resp) }
      it { is_expected.to eq(resp) }
    end

    context 'with invalid subscriber' do
      let(:ret_sub) { nil }

      it { expect { execute }.to raise_error(Cloudenvoy::InvalidSubscriberError) }
    end
  end

  describe '.cloudenvoy_options_hash' do
    subject { subscriber_class.cloudenvoy_options_hash }

    let(:opts) { { foo: 'bar' } }
    let!(:original_opts) { subscriber_class.cloudenvoy_options_hash }

    before { subscriber_class.cloudenvoy_options(opts) }
    after { subscriber_class.cloudenvoy_options(original_opts) }
    it { is_expected.to eq(Hash[opts.map { |k, v| [k.to_sym, v] }]) }
  end

  describe '.topics' do
    subject { subscriber_class.topics }

    it { is_expected.to eq(subscriber_class.cloudenvoy_options_hash.fetch(:topics)) }
  end

  describe '.subscription_name' do
    subject { subscriber_class.subscription_name(topic) }

    let(:expected) do
      [
        Cloudenvoy.config.gcp_sub_prefix.tr('.', '-'),
        subscriber_class.to_s.underscore,
        topic
      ]
    end

    context 'with regular prefix name' do
      it { is_expected.to eq(expected) }
    end

    context 'with dotted prefix' do
      before { allow(Cloudenvoy.config).to receive(:gcp_sub_prefix).and_return('foo.bar') }
      it { is_expected.to eq(expected) }
    end
  end

  describe '.setup' do
    subject { subscriber_class.setup }

    let(:topics) { %w[foo bar] }
    let(:gcp_subs) { Array.new(2) { instance_double('Google::Cloud::PubSub::Subscription') } }

    before do
      allow(subscriber_class).to receive(:topics).and_return(topics)
      topics.each_with_index do |t, i|
        expect(Cloudenvoy::PubSubClient).to receive(:upsert_subscription)
          .with(t, subscriber_class.subscription_name(t))
          .and_return(gcp_subs[i])
      end
    end

    it { is_expected.to eq(gcp_subs) }
  end

  describe '.new' do
    subject { subscriber }

    it { is_expected.to have_attributes(message: message) }
  end

  describe '#logger' do
    subject { subscriber.logger }

    it { is_expected.to be_a(Cloudenvoy::SubscriberLogger) }
    it { is_expected.to have_attributes(loggable: subscriber) }
  end

  describe '#execute' do
    subject { subscriber.execute }

    let(:resp) { 'some-resp' }

    before { expect(subscriber).to receive(:process).with(message).and_return(resp) }
    it { is_expected.to eq(resp) }
  end

  describe '#==' do
    subject { subscriber }

    it { is_expected.to eq(TestSubscriber.new(message: message)) }
    it { is_expected.not_to eq(TestSubscriber.new(message: 'bar')) }
    it { is_expected.not_to eq('foo') }
  end
end