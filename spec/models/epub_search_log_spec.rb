# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EpubSearchLog, type: :model do
  subject { described_class.new(args) }

  let(:args) { { noid: 'validnoid', query: 'dog', time: 43, hits: 2, search_results: "{:q=>\"dog\", :search_results=>[]}", user: "user@fulcrum.org", press: "subdomain" } }

  it 'is valid' do
    expect(subject).to be_valid
    expect(subject.errors.messages).to be_empty
    expect(subject.save!).to be true
    expect(subject.destroy!).to be subject
  end

  describe "#to_csv" do
    let(:created_at) { Time.zone.now }

    before do
      args[:created_at] = created_at
      @log = EpubSearchLog.create!(args)
    end

    it "returns csv" do
      expect(described_class.to_csv).to eq <<-EOT
id,noid,query,time,hits,created_at,user,press
#{@log.id},validnoid,dog,43,2,#{created_at},user@fulcrum.org,subdomain
      EOT
    end
  end
end
