# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/e_pub_helper'

RSpec.describe EPub::EPubNullObject do
  describe '#new' do
    it 'private_class_method' do
      expect { is_expected }.to raise_error(NoMethodError)
    end
  end

  describe '#id' do
    subject { EPub::EPub.null_object.id }

    it 'returns "epub_null"' do
      is_expected.to eq 'epub_null'
    end
  end

  describe '#read' do
    subject { EPub::EPub.null_object.read(nil) }

    it 'returns an empty string' do
      is_expected.to be_a(String)
      is_expected.to be_empty
    end
  end

  describe '#search' do
    subject { EPub::EPub.null_object.search(query) }

    let(:query) { double("query") }

    it 'returns an empty results hash' do
      is_expected.to be_a(Hash)
      expect(subject[:q]).to eq query
      expect(subject[:search_results]).to eq([])
    end
  end
end
