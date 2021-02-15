RSpec.describe Hermes::Logger::ParamsFilter do
  describe "#call" do
    context "with default config for initialization" do
      subject(:call) { described_class.new.call(attribute, value) }

      let(:value) { "value" }

      describe "for attributes containing 'token' word" do
        let(:attribute) { :access_token }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'password' word" do
        let(:attribute) { :password_confirmation }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'credit_card' word" do
        let(:attribute) { :credit_card }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'card_number' word" do
        let(:attribute) { :card_number }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'card_number' word" do
        let(:attribute) { :card_number }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'verification_value' word" do
        let(:attribute) { :verification_value }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'private_key' word" do
        let(:attribute) { :private_key }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'signature' word" do
        let(:attribute) { :signature }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'api_key' word" do
        let(:attribute) { :api_key }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'secret_key' word" do
        let(:attribute) { :secret_key }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for attributes containing 'publishable_key' word" do
        let(:attribute) { :publishable_key }

        it { is_expected_block.to change { value }.from("value").to("[STRIPPED]") }
      end

      describe "for other attributes" do
        let(:attribute) { :currency }

        it { is_expected_block.not_to change { value } }
      end
    end

    context "with custom config for initialization" do
      subject(:call) { params_filter.call(attribute, value) }

      let(:params_filter) { described_class.new(sensitive_keywords: %i(magic_attribute), stripped_value: "[removed]") }
      let(:value) { "value" }

      describe "for attributes containing 'publishable_key' word" do
        let(:attribute) { :magic_attribute }

        it { is_expected_block.to change { value }.from("value").to("[removed]") }
      end

      describe "for other attributes" do
        let(:attribute) { :password }

        it { is_expected_block.not_to change { value } }
      end
    end
  end
end